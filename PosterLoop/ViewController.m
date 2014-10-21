//
//  ViewController.m
//  PosterLoop
//
//  Created by Moses DeJong on 10/19/14.
//  Copyright (c) 2014 helpurock. All rights reserved.
//

#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>

#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVAssetReader.h>
#import <AVFoundation/AVAssetReaderOutput.h>

#import <CoreMedia/CMSampleBuffer.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

  NSAssert(self.imageView, @"imageView");
  
  self.view.backgroundColor = [UIColor greenColor];
  
  self.imageView.image = [UIImage imageNamed:@"question"];

  // Give app a little time to start up and begin processing events
  
  if (TRUE) {
  
  NSTimer *timer = [NSTimer timerWithTimeInterval: 1.0
                                           target: self
                                         selector: @selector(loadVideoContent)
                                         userInfo: NULL
                                          repeats: FALSE];
  
	[[NSRunLoop currentRunLoop] addTimer:timer forMode: NSDefaultRunLoopMode];
    
  }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
  
    NSLog(@"didReceiveMemoryWarning");
}

- (NSString*) getResourcePath:(NSString*)resFilename
{
	NSBundle* appBundle = [NSBundle mainBundle];
	NSString* movieFilePath = [appBundle pathForResource:resFilename ofType:nil];
  NSAssert(movieFilePath, @"movieFilePath is nil");
	return movieFilePath;
}

// This method does a blocking load from 2 video input sources, the result
// is a series of PNG images.

- (void) loadVideoContent
{
  BOOL worked;
  
  // Define animated images in terms of the tmp path
  
  self.aniPrefix = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Poster"];
  self.aniSuffix = ([UIScreen mainScreen].scale == 1.0f) ? @"" : @"@2x";
  
  NSString *rgbFilename = @"Poster_rgb_CRF_15_24BPP.m4v";
  NSString *alphaFilename = @"Poster_alpha_CRF_15_24BPP.m4v";
  
  NSString *rgbPath = [self getResourcePath:rgbFilename];
  NSString *alphaPath = [self getResourcePath:alphaFilename];
  
  NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                      forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
  
  NSURL *urlRGB = [NSURL fileURLWithPath:rgbPath];
  NSURL *urlAlpha = [NSURL fileURLWithPath:alphaPath];
  
  AVURLAsset *avUrlAssetRGB = [[AVURLAsset alloc] initWithURL:urlRGB options:options];
  NSAssert(avUrlAssetRGB, @"AVURLAsset");

  AVURLAsset *avUrlAssetAlpha = [[AVURLAsset alloc] initWithURL:urlAlpha options:options];
  NSAssert(avUrlAssetAlpha, @"AVURLAsset");

  NSError *assetError = nil;
  
  AVAssetReader *aVAssetReaderRGB = [[AVAssetReader alloc] initWithAsset:avUrlAssetRGB error:nil];
  NSAssert(aVAssetReaderRGB, @"aVAssetReaderRGB");
  
  AVAssetReader *aVAssetReaderAlpha = [[AVAssetReader alloc] initWithAsset:avUrlAssetAlpha error:nil];
  NSAssert(aVAssetReaderAlpha, @"aVAssetReaderAlpha");
  
  // This video setting indicates that native 32 bit endian pixels with a leading
  // ignored alpha channel will be emitted by the decoding process.
  
  NSDictionary *videoSettings;
  videoSettings = [NSDictionary dictionaryWithObject:
                   [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
  
    NSArray *videoTracksRGB = [avUrlAssetRGB tracksWithMediaType:AVMediaTypeVideo];
  
  NSAssert([videoTracksRGB count] == 1, @"only 1 video track can be decoded");
  
  AVAssetTrack *videoTrackRGB = [videoTracksRGB objectAtIndex:0];
  
  NSArray *videoTracksAlpha =  [avUrlAssetAlpha tracksWithMediaType:AVMediaTypeVideo];
  
  NSAssert([videoTracksAlpha count] == 1, @"only 1 video track can be decoded");
  
  AVAssetTrack *videoTrackAlpha = [videoTracksAlpha objectAtIndex:0];

    AVAssetReaderTrackOutput *aVAssetReaderOutputRGB = [AVAssetReaderTrackOutput
                                                        assetReaderTrackOutputWithTrack:videoTrackRGB
                                                        outputSettings:videoSettings];
  
    [aVAssetReaderRGB addOutput:aVAssetReaderOutputRGB];
    AVAssetReaderTrackOutput *outputRGB = [aVAssetReaderRGB.outputs objectAtIndex:0];

    AVAssetReaderTrackOutput *aVAssetReaderOutputAlpha = [AVAssetReaderTrackOutput
                                                          assetReaderTrackOutputWithTrack:videoTrackAlpha
                                                          outputSettings:videoSettings];

   // connect aVAssetReaderAlpha to aVAssetReaderOutputAlpha here
    [aVAssetReaderAlpha addOutput:aVAssetReaderOutputAlpha];
    AVAssetReaderTrackOutput *outputAlpha = [aVAssetReaderAlpha.outputs objectAtIndex:0];

  worked = [aVAssetReaderRGB startReading];
  NSAssert(worked, @"AVAssetReaderVideoCompositionOutput failed");
  
  worked = [aVAssetReaderAlpha startReading];
  NSAssert(worked, @"AVAssetReaderVideoCompositionOutput failed");
  
  // numFrames is hard coded to 21 here to avoid having to calculate based on video duration
  
  const int numFrames = 21;

  for (int i = 0 ; i < numFrames ; i++) @autoreleasepool {
    CMSampleBufferRef sampleBufferRGB = NULL;
      sampleBufferRGB = [outputRGB copyNextSampleBuffer];
    
    CMSampleBufferRef sampleBufferAlpha = NULL;
      sampleBufferAlpha = [outputAlpha copyNextSampleBuffer];

    UIImage *maskedImg = [self renderAsUIImage:sampleBufferRGB sampleBufferAlpha:sampleBufferAlpha];
    
    CFRelease(sampleBufferRGB);
    CFRelease(sampleBufferAlpha);
    
      NSData *imageData = UIImagePNGRepresentation(maskedImg);
    
    NSString *outPngFilename = [NSString stringWithFormat:@"Poster%d%@.png", i, self.aniSuffix];

    NSString *outPngPath = [NSTemporaryDirectory() stringByAppendingPathComponent:outPngFilename];
    
    worked = [imageData writeToFile:outPngPath atomically:TRUE];
    NSAssert(worked, @"png writeToFile failed");
    
    NSLog(@"write %@", outPngFilename);
  }

  [aVAssetReaderRGB cancelReading];
  [aVAssetReaderAlpha cancelReading];

  // kick off animation timer
  
  NSTimer *timer = [NSTimer timerWithTimeInterval: 0.1
                                           target: self
                                         selector: @selector(animateStep)
                                         userInfo: NULL
                                          repeats: TRUE];
  
	[[NSRunLoop currentRunLoop] addTimer:timer forMode: NSDefaultRunLoopMode];
  
  return;
}

// Render RGB and Alpha data into a UIImage

- (UIImage *) renderAsUIImage:(CMSampleBufferRef)sampleBufferRGB
            sampleBufferAlpha:(CMSampleBufferRef)sampleBufferAlpha
{
  CVImageBufferRef imageBufferRGB = CMSampleBufferGetImageBuffer(sampleBufferRGB);
  CVImageBufferRef imageBufferAlpha = CMSampleBufferGetImageBuffer(sampleBufferAlpha);
  
  CVPixelBufferLockBaseAddress(imageBufferRGB, 0);
  CVPixelBufferLockBaseAddress(imageBufferAlpha, 0);
  
  // Under iOS, the output pixels are always as sRGB.
  
  CGColorSpaceRef colorSpace = NULL;

  colorSpace = CGColorSpaceCreateDeviceRGB();

  NSAssert(colorSpace, @"colorSpace");
  
  // Create a Quartz direct-access data provider that uses data we supply.
  
  CGDataProviderRef dataProviderRGB =
  CGDataProviderCreateWithData(NULL,
                               CVPixelBufferGetBaseAddress(imageBufferRGB),
                               CVPixelBufferGetDataSize(imageBufferRGB), NULL);
  
  CGDataProviderRef dataProviderAlpha =
  CGDataProviderCreateWithData(NULL,
                               CVPixelBufferGetBaseAddress(imageBufferAlpha),
                               CVPixelBufferGetDataSize(imageBufferAlpha), NULL);
  
  CGImageRef cgImageRefRGB = CGImageCreate(CVPixelBufferGetWidth(imageBufferRGB),
                                        CVPixelBufferGetHeight(imageBufferRGB),
                                        8, 32, CVPixelBufferGetBytesPerRow(imageBufferRGB),
                                        colorSpace, kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst,
                                        dataProviderRGB, NULL, true, kCGRenderingIntentDefault);

  CGImageRef cgImageRefAlpha = CGImageCreate(CVPixelBufferGetWidth(imageBufferAlpha),
                                           CVPixelBufferGetHeight(imageBufferAlpha),
                                           8, 32, CVPixelBufferGetBytesPerRow(imageBufferAlpha),
                                           colorSpace, kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst,
                                           dataProviderAlpha, NULL, true, kCGRenderingIntentDefault);

  
	CGColorSpaceRelease(colorSpace);
  
  UIImage *img = [self.class renderMaskedUIImage:cgImageRefRGB maskImgRef:cgImageRefAlpha];

  CGImageRelease(cgImageRefRGB);
  CGImageRelease(cgImageRefAlpha);
  
  CGDataProviderRelease(dataProviderRGB);
  CGDataProviderRelease(dataProviderAlpha);
  
  CVPixelBufferUnlockBaseAddress(imageBufferRGB, 0);
  CVPixelBufferUnlockBaseAddress(imageBufferAlpha, 0);
  
  return img;
}

+ (UIImage*) renderMaskedUIImage:(CGImageRef)rgbImageRef
                      maskImgRef:(CGImageRef)maskImgRef
{
  // Create non-opaque ABGR bitmap the same size as the image, with the screen scale
  
  CGSize size = CGSizeMake(CGImageGetWidth(rgbImageRef), CGImageGetHeight(rgbImageRef));
  
  int scale = (int) [UIScreen mainScreen].scale;
  
  if (scale == 1) {
    // No-op
  } else if (scale == 2) {
    size.width = size.width / 2;
    size.height = size.height / 3;
  } else {
    // WTF ?
    NSAssert(FALSE, @"unhandled scale %d", scale);
  }
  
  UIGraphicsBeginImageContextWithOptions(size, FALSE, scale);
  
  CGRect frame = CGRectZero;
  frame.size = size;
  
  CGContextRef currentContext = UIGraphicsGetCurrentContext();
  NSAssert(currentContext != nil, @"currentContext");
  
  CGContextTranslateCTM(currentContext, 0.0, size.height);
  CGContextScaleCTM(currentContext, 1.0, -1.0);
  
  CGContextClipToMask(currentContext, frame, maskImgRef);
  
  CGContextDrawImage(currentContext, frame, rgbImageRef);
  
  UIImage *rendered = UIGraphicsGetImageFromCurrentImageContext();
  
  // pop the context to get back to the default
  UIGraphicsEndImageContext();
  
  return rendered;
}

- (void) animateStep
{
  NSString *path = [NSString stringWithFormat:@"%@%d%@.png", self.aniPrefix, self.aniStep, self.aniSuffix];
  
    self.imageView.image = [UIImage imageWithContentsOfFile:path];
  
  int scale = (int) [UIScreen mainScreen].scale;
    
  NSLog(@"loaded \"%@\" with scale %d", path, (int)self.imageView.image.scale);
  
  if (self.aniStep == 21-1) {
    self.aniStep = 0;
  } else {
    self.aniStep = self.aniStep + 1;
  }
}

@end
