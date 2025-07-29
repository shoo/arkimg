module src.main;

import webp.encode, webp.decode;
import arkimg.bmp, arkimg.webp, arkimg.utils;
import std.file, std.exception, std.algorithm, std.range, std.array;

void main()
{
	//createWebp();
	//createBmp();
	auto key = cast(immutable(ubyte)[])x"01020304050607080910111213141516";
	auto bmpBuf1 = cast(ubyte[])std.file.read("../.resources/d-man.bmp");
	auto bmpImg1 = createBitmap(bmpBuf1);
	auto arkimg1 = new ArkWebp;
	arkimg1.baseImage(bmpBuf1, "image/bmp");
	arkimg1.setKey(key);
	arkimg1.addSecretItem(cast(ubyte[])"test_testtest_test");
	auto webpBuf = arkimg1.save();
	std.file.write("test.webp", webpBuf);
	
	auto arkimg2 = loadImage(webpBuf, "image/webp", key);
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
	
	auto imgPng = loadImage("../.resources/d-man.png");
	auto bufPng2Webp = saveImage(imgPng, "image/webp", key);
	std.file.write("test2.webp", bufPng2Webp);
	auto imgWebp2 = loadImage("test2.webp");
	auto bufWebp2Png = saveImage(imgWebp2, "image/png", key);
	std.file.write("test3.png", bufWebp2Png);
	auto imgPng2 = loadImage(bufWebp2Png, "image/png", key);
	auto bmpImg3 = createBitmap(imgPng2.baseImage("image/bmp"));
	
	diff = 0.0L;
	foreach (r; 0..bmpImg3.size.height)
		diff += (bmpImg3.row(r).sum(real(0)) / bmpImg3.size.width)  // avg width
		      - (bmpImg2.row(r).sum(real(0)) / bmpImg2.size.width); // avg width
	diff /= bmpImg3.size.height; // avg height
	diff /= 3; // avg channel
	// 1ドットにつき差異が 0～255 中 平均 1.0 未満であること
	assert(diff > -1.0L && diff < 1.0L);
}
