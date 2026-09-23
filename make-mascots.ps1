# Cut the two cartoon doctors out of the clinic poster and drop the pink
# background, writing transparent PNGs. Both cuts use the same 190x238 frame
# so the two figures render at an identical size on the page.
#
# The white lab coats sit only ~22 apart from the pink background in RGB, so a
# plain colour key would eat them. Instead we flood fill inward from the border
# and clear only background that is CONNECTED to the outside, which the figures'
# black outlines stop. Seeds come from the top/left/right edges only: the frame
# cuts through the body at the bottom, so that edge is not background.
Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class Cutout
{
    static byte[] Buf;
    static int Stride, W, H, BgR, BgG, BgB;

    static int Dist(int x, int y)
    {
        int k = y * Stride + x * 4;
        int db = Math.Abs(Buf[k]     - BgB);
        int dg = Math.Abs(Buf[k + 1] - BgG);
        int dr = Math.Abs(Buf[k + 2] - BgR);
        return Math.Max(dr, Math.Max(dg, db));
    }

    public static string Run(string src, string dst, int X, int Y, int w, int h,
                             int bgR, int bgG, int bgB, int seedTol, int fillTol, int featherTo, int minBlob)
    {
        W = w; H = h; BgR = bgR; BgG = bgG; BgB = bgB;

        Bitmap source = new Bitmap(src);
        Bitmap bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        Graphics g = Graphics.FromImage(bmp);
        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
        g.DrawImage(source, new Rectangle(0, 0, W, H), X, Y, W, H, GraphicsUnit.Pixel);
        g.Dispose();
        source.Dispose();

        Rectangle r = new Rectangle(0, 0, W, H);
        BitmapData bd = bmp.LockBits(r, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        Stride = bd.Stride;
        Buf = new byte[Stride * H];
        Marshal.Copy(bd.Scan0, Buf, 0, Buf.Length);

        bool[] mask = new bool[W * H];
        int[] stack = new int[W * H];
        int sp = 0;

        // seed: top edge, plus left and right edges
        for (int x = 0; x < W; x++)
            if (Dist(x, 0) <= seedTol && !mask[x]) { mask[x] = true; stack[sp++] = x; }
        for (int y = 0; y < H; y++)
        {
            int a = y * W, b = y * W + (W - 1);
            if (Dist(0, y) <= seedTol && !mask[a]) { mask[a] = true; stack[sp++] = a; }
            if (Dist(W - 1, y) <= seedTol && !mask[b]) { mask[b] = true; stack[sp++] = b; }
        }

        while (sp > 0)
        {
            int idx = stack[--sp];
            int x = idx % W, y = idx / W;
            if (x > 0     && !mask[idx - 1] && Dist(x - 1, y) <= fillTol) { mask[idx - 1] = true; stack[sp++] = idx - 1; }
            if (x < W - 1 && !mask[idx + 1] && Dist(x + 1, y) <= fillTol) { mask[idx + 1] = true; stack[sp++] = idx + 1; }
            if (y > 0     && !mask[idx - W] && Dist(x, y - 1) <= fillTol) { mask[idx - W] = true; stack[sp++] = idx - W; }
            if (y < H - 1 && !mask[idx + W] && Dist(x, y + 1) <= fillTol) { mask[idx + W] = true; stack[sp++] = idx + W; }
        }

        int cleared = 0, feathered = 0;
        for (int y = 0; y < H; y++)
        {
            for (int x = 0; x < W; x++)
            {
                int idx = y * W + x, k = y * Stride + x * 4;
                if (mask[idx]) { Buf[k + 3] = 0; cleared++; continue; }

                // soften pixels that touch cleared background so no pink rim survives
                bool edge = (x > 0 && mask[idx - 1]) || (x < W - 1 && mask[idx + 1])
                         || (y > 0 && mask[idx - W]) || (y < H - 1 && mask[idx + W]);
                if (!edge) continue;
                int d = Dist(x, y);
                if (d < featherTo)
                {
                    Buf[k + 3] = (byte)Math.Round((d - fillTol) * 255.0 / (featherTo - fillTol));
                    feathered++;
                }
            }
        }

        // drop stray specks: opaque blobs too small to be part of the figure
        // (stubs of a neighbouring photo panel clipped by the frame, etc.)
        bool[] seen = new bool[W * H];
        int[] blob = new int[W * H];
        int wiped = 0;
        for (int start = 0; start < W * H; start++)
        {
            if (seen[start]) continue;
            int sx = start % W, sy = start / W;
            if (Buf[sy * Stride + sx * 4 + 3] == 0) { seen[start] = true; continue; }

            int n = 0; sp = 0; stack[sp++] = start; seen[start] = true;
            while (sp > 0)
            {
                int idx = stack[--sp];
                blob[n++] = idx;
                int x = idx % W, y = idx / W;
                int[] nb = new int[] { x > 0 ? idx - 1 : -1, x < W - 1 ? idx + 1 : -1,
                                       y > 0 ? idx - W : -1, y < H - 1 ? idx + W : -1 };
                for (int q = 0; q < 4; q++)
                {
                    int m = nb[q];
                    if (m < 0 || seen[m]) continue;
                    int mx = m % W, my = m / W;
                    if (Buf[my * Stride + mx * 4 + 3] == 0) continue;
                    seen[m] = true; stack[sp++] = m;
                }
            }
            if (n < minBlob)
            {
                for (int q = 0; q < n; q++)
                {
                    int idx = blob[q];
                    Buf[(idx / W) * Stride + (idx % W) * 4 + 3] = 0;
                }
                wiped += n;
            }
        }

        Marshal.Copy(Buf, 0, bd.Scan0, Buf.Length);
        bmp.UnlockBits(bd);
        bmp.Save(dst, ImageFormat.Png);
        bmp.Dispose();

        return string.Format("{0}x{1}  transparent {2}%  feathered {3}px  wiped {4}px",
            W, H, Math.Round(100.0 * cleared / (W * H), 1), feathered, wiped);
    }
}
'@

$src = 'C:\MyProjects7\mascots.jpg'
# background #FFF0E9; seed 10, fill 18 (white coat sits at 22, so it is safe), feather to 46

# Both frames are 190x238. Measured in the poster the two heads are nearly the
# same size already (hers 137px wide with the top of the hair at y=478, his
# 131px with the top at y=348), so an identical frame renders them at an
# identical size. Each frame is placed to sit about 22px above the hair.
Write-Output ("mascot-a.png  " + [Cutout]::Run($src, 'C:\MyProjects7\mascot-a.png', 116, 456, 190, 238, 255, 240, 233, 10, 18, 46, 400))
# his frame is a touch tighter (176x220, same 190:238 aspect) so that at the same
# display height his head reads slightly larger than hers
Write-Output ("mascot-b.png  " + [Cutout]::Run($src, 'C:\MyProjects7\mascot-b.png', 906, 328, 176, 220, 255, 240, 233, 10, 18, 46, 400))
