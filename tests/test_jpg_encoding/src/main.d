module src.main;

import libjpeg.turbojpeg;
import arkimg.bmp;
import std.algorithm;
import std.file, std.path;
import arkimg.jpg;
import arkimg.utils;

void main()
{
	auto key = cast(immutable(ubyte)[])x"01020304050607080910111213141516";
	auto bmpBuf1 = cast(ubyte[])std.file.read("../.resources/d-man.bmp");
	auto bmpImg1 = createBitmap(bmpBuf1);
	auto arkimg1 = new ArkJpeg;
	arkimg1.baseImage(bmpBuf1, "image/bmp");
	arkimg1.setKey(key);
	arkimg1.addSecretItem(cast(ubyte[])"test_testtest_test");
	auto jpgBuf = arkimg1.save();
	std.file.write("test.jpg", jpgBuf);
	
	auto arkimg2 = loadImage(jpgBuf, "image/jpeg", key);
	auto itm = arkimg2.getDecryptedItem(0);
	assert(itm == cast(ubyte[])"test_testtest_test");
	auto bmpBuf2 = arkimg2.baseImage("image/bmp");
	std.file.write("test.bmp", bmpBuf2);
	auto bmpImg2 = createBitmap(bmpBuf2);
	
	real diff = 0.0L;
	foreach (r; 0..bmpImg1.size.height)
		diff += (bmpImg1.row(r).sum(real(0)) / bmpImg1.size.width)  // avg width
		      - (bmpImg2.row(r).sum(real(0)) / bmpImg2.size.width); // avg width
	diff /= bmpImg1.size.height; // avg height
	diff /= 3; // avg channel
	// 1ドットにつき差異が 0～255 中 平均 1.0 未満であること
	assert(diff > -1.0L && diff < 1.0L);
}

