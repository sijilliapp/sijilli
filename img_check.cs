using System;
using System.Drawing;
using System.IO;

class Program
{
    static void Main()
    {
        string dir = @"j:\sijilli\docs\ScreenSotes_store";
        string[] files = Directory.GetFiles(dir);
        foreach (string file in files)
        {
            if (file.EndsWith(".png") || file.EndsWith(".jpg"))
            {
                try {
                    using (Image img = Image.FromFile(file))
                    {
                        Console.WriteLine($"{Path.GetFileName(file)} | {img.Width}x{img.Height}");
                    }
                } catch { }
            }
        }
    }
}
