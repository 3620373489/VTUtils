//
//  SDAVAssetExportSession.m
//
// This file is part of the SDAVAssetExportSession package.
//
// Created by Olivier Poitrey <rs@dailymotion.com> on 13/03/13.
// Copyright 2013 Olivier Poitrey. All rights servered.
//
// For the full copyright and license information, please view the LICENSE
// file that was distributed with this source code.
//


#import "SDAVAssetExportSession.h"

////-for debug
#import "coreMediaPrint.h"
////-for debug


@interface SDAVAssetExportSession ()

@property (nonatomic, assign, readwrite) float progress;

@property (nonatomic, strong) AVAssetReader *reader;


@property (nonatomic, strong) AVAssetReaderVideoCompositionOutput *videoOutput;


////-dli
////@property (nonatomic, strong) AVAssetReaderTrackOutput * videoOutput;
////-dli



@property (nonatomic, strong) AVAssetReaderAudioMixOutput *audioOutput;

@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *videoPixelBufferAdaptor;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;
@property (nonatomic, strong) dispatch_queue_t inputQueue;
@property (nonatomic, strong) void (^completionHandler)();

@end

@implementation SDAVAssetExportSession
{
    NSError *_error;
    NSTimeInterval duration;
    CMTime lastSamplePresentationTime;
}

+ (id)exportSessionWithAsset:(AVAsset *)asset
{
    return [SDAVAssetExportSession.alloc initWithAsset:asset];
}

- (id)initWithAsset:(AVAsset *)asset
{
    if ((self = [super init]))
    {
        _asset = asset;
        _timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
    }

    return self;
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)())handler
{
    NSParameterAssert(handler != nil);
    [self cancelExport];
    self.completionHandler = handler;

    if (!self.outputURL)
    {
        _error = [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorExportFailed userInfo:@
        {
            NSLocalizedDescriptionKey: @"Output URL not set"
        }];
        handler();
        return;
    }

    NSError *readerError;
    self.reader = [AVAssetReader.alloc initWithAsset:self.asset error:&readerError];
    if (readerError)
    {
        _error = readerError;
        handler();
        return;
    }

    NSError *writerError;
    self.writer = [AVAssetWriter assetWriterWithURL:self.outputURL fileType:self.outputFileType error:&writerError];
    if (writerError)
    {
        _error = writerError;
        handler();
        return;
    }

    self.reader.timeRange = self.timeRange;
    self.writer.shouldOptimizeForNetworkUse = self.shouldOptimizeForNetworkUse;
    self.writer.metadata = self.metadata;
    
    
    
    

    NSArray *videoTracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
    CGSize renderSize;
    if (self.videoComposition)
    {
        renderSize = self.videoComposition.renderSize;
    }
    else if (videoTracks.count)
    {
        renderSize = ((AVAssetTrack *)videoTracks[0]).naturalSize;
    }

    if (CMTIME_IS_VALID(self.timeRange.duration) && !CMTIME_IS_POSITIVE_INFINITY(self.timeRange.duration))
    {
        duration = CMTimeGetSeconds(self.timeRange.duration);
    }
    else
    {
        duration = CMTimeGetSeconds(self.asset.duration);
    }
    //
    // Video output
    //
    if (videoTracks.count > 0) {
        self.videoOutput = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:videoTracks videoSettings:self.videoInputSettings];
        
        
        
        /*
        ////-dli
        int m_pixelFormatType;
        m_pixelFormatType = kCVPixelFormatType_32BGRA;
        NSMutableDictionary *options = [NSMutableDictionary dictionary];
        [options setObject:@(m_pixelFormatType) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        self.videoOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTracks[0] outputSettings:options];
        ////-dli
        */
        
        
        for (int i=0; i<videoTracks.count; i++) {
            NSLog(@"[[[[[[[%@]]]]]]]",getVideoTrack_I_Descs(videoTracks,i));
        }
        
        
        NSLog(@"===========================================");
        
        NSLog(@"self.videoInputSettings:%@",self.videoInputSettings);
        
        NSLog(@"===========================================");
        self.videoOutput.alwaysCopiesSampleData = NO;
        
        
        NSLog(@"self.videoComposition:%@",self.videoComposition);
        
        if (self.videoComposition)
        {
            ////self.videoOutput.videoComposition = self.videoComposition;
        }
        else
        {
            
            
            NSLog(@"<<<<<<<<<<<<using self.asset VideoComposition  >>>>>>>>>>>>>>>>>>");
            self.videoOutput.videoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:self.asset];
            
            ////NSLog(@"<<<<<<<<<<<<using buildDefaultVideoComposition >>>>>>>>>>>>>>>>>>");
            ////[self buildDefaultVideoComposition];
            
            
        }
        if ([self.reader canAddOutput:self.videoOutput])
        {
            [self.reader addOutput:self.videoOutput];
        }

        //
        // Video input
        //
        self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:self.videoSettings];
        
        
        ////self.videoInput.expectsMediaDataInRealTime = NO;
        
        ////-dli
        self.videoInput.expectsMediaDataInRealTime = YES;
        ////-dli
        
        
        if ([self.writer canAddInput:self.videoInput])
        {
            [self.writer addInput:self.videoInput];
        }
        
        
        ////kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ////kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ////kCVPixelFormatType_32BGRA
        
        
        
        
        
        NSDictionary *pixelBufferAttributes = @
        {
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
            (id)kCVPixelBufferWidthKey: @(renderSize.width),
            (id)kCVPixelBufferHeightKey: @(renderSize.height),
            @"IOSurfaceOpenGLESTextureCompatibility": @YES,
            @"IOSurfaceOpenGLESFBOCompatibility": @YES,
        };
        self.videoPixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoInput sourcePixelBufferAttributes:pixelBufferAttributes];
    }

    //
    //Audio output
    //
    NSArray *audioTracks = [self.asset tracksWithMediaType:AVMediaTypeAudio];
    if (audioTracks.count > 0) {
      self.audioOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:audioTracks audioSettings:nil];
      self.audioOutput.alwaysCopiesSampleData = NO;
      self.audioOutput.audioMix = self.audioMix;
      if ([self.reader canAddOutput:self.audioOutput])
      {
          [self.reader addOutput:self.audioOutput];
      }
    } else {
        // Just in case this gets reused
        self.audioOutput = nil;
    }

    //
    // Audio input
    //
    if (self.audioOutput) {
        self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:self.audioSettings];
        self.audioInput.expectsMediaDataInRealTime = NO;
        if ([self.writer canAddInput:self.audioInput])
        {
            [self.writer addInput:self.audioInput];
        }
    }
    
    [self.writer startWriting];
    [self.reader startReading];
    if (videoTracks.count > 0)
        [self.writer startSessionAtSourceTime:CMTimeMake(0, ((AVAssetTrack *)videoTracks[0]).naturalTimeScale)];
    else
        [self.writer startSessionAtSourceTime:CMTimeMake(0, ((AVAssetTrack *)audioTracks[0]).naturalTimeScale)];        

    __block BOOL videoCompleted = NO;
    __block BOOL audioCompleted = NO;
    __weak typeof(self) wself = self;
    self.inputQueue = dispatch_queue_create("VideoEncoderInputQueue", DISPATCH_QUEUE_SERIAL);
    if (videoTracks.count > 0) {
        [self.videoInput requestMediaDataWhenReadyOnQueue:self.inputQueue usingBlock:^
        {
            if (![wself encodeReadySamplesFromOutput:wself.videoOutput toInput:wself.videoInput])
            {
                @synchronized(wself)
                {
                    videoCompleted = YES;
                    if (audioCompleted)
                    {
                        [wself finish];
                    }
                }
            }
        }];
    }
    else {
        videoCompleted = YES;
    }
    
    if (!self.audioOutput) {
        audioCompleted = YES;
    } else {
        [self.audioInput requestMediaDataWhenReadyOnQueue:self.inputQueue usingBlock:^
         {
             if (![wself encodeReadySamplesFromOutput:wself.audioOutput toInput:wself.audioInput])
             {
                 @synchronized(wself)
                 {
                     audioCompleted = YES;
                     if (videoCompleted)
                     {
                         [wself finish];
                     }
                 }
             }
         }];
    }
}

- (BOOL)encodeReadySamplesFromOutput:(AVAssetReaderOutput *)output toInput:(AVAssetWriterInput *)input
{
    while (input.isReadyForMoreMediaData)
    {
        CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];
        if (sampleBuffer)
        {
            
            ////-dli
            
            NSLog(@"dli--%@---dli",CMSampleBufferGetImageBuffer(sampleBuffer));
            
            ////-dli
            
            
            BOOL handled = NO;
            BOOL error = NO;

            if (self.reader.status != AVAssetReaderStatusReading || self.writer.status != AVAssetWriterStatusWriting)
            {
                
                ////-dli
                
                NSLog(@"dli--@@@@@@@@@@@@@@@@@@@@@@@--brance1-----@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@----dli");
                
                ////-dli
                
                handled = YES;
                error = YES;
            }
            
            if (!handled && self.videoOutput == output)
            {
                
                ////-dli
                
                NSLog(@"dli--@@@@@@@@@@@@@@@@@@@@@@@--brance2-----@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@----dli");
                
                ////-dli
                
                // update the video progress
                lastSamplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                self.progress = duration == 0 ? 1 : CMTimeGetSeconds(lastSamplePresentationTime) / duration;

                if ([self.delegate respondsToSelector:@selector(exportSession:renderFrame:withPresentationTime:toBuffer:)])
                {
                    
                    
                    
                    ////-dli
                    
                    NSLog(@"dli--@@@@@@@@@@@@@@@@@@@@@@@--brance3-----@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@----dli");
                    
                    ////-dli
                    
                    
                    
                    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
                    

                    
                    
                    
                    CVPixelBufferRef renderBuffer = NULL;
                    CVPixelBufferPoolCreatePixelBuffer(NULL, self.videoPixelBufferAdaptor.pixelBufferPool, &renderBuffer);
                    [self.delegate exportSession:self renderFrame:pixelBuffer withPresentationTime:lastSamplePresentationTime toBuffer:renderBuffer];
                    if (![self.videoPixelBufferAdaptor appendPixelBuffer:renderBuffer withPresentationTime:lastSamplePresentationTime])
                    {
                        
                        ////-dli
                        
                        NSLog(@"dli--@@@@@@@@@@@@@@@@@@@@@@@--brance4-----@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@----dli");
                        
                        ////-dli
                        
                        error = YES;
                    }
                    CVPixelBufferRelease(renderBuffer);
                    handled = YES;
                }
            }
            
            
            if (!handled && ![input appendSampleBuffer:sampleBuffer])
            {
                
                ////-dli
                
                NSLog(@"dli--@@@@@@@@@@@@@@@@@@@@@@@--brance5-----@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@----dli");
                
                ////-dli
                
                error = YES;
            }
            CFRelease(sampleBuffer);

            if (error)
            {
                
                
                ////-dli
                
                NSLog(@"dli--@@@@@@@@@@@@@@@@@@@@@@@--brance6-----@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@----dli");
                
                ////-dli
                
                return NO;
            }
        }
        else
        {
            [input markAsFinished];
            return NO;
        }
    }

    return YES;
}

- (AVMutableVideoComposition *)buildDefaultVideoComposition
{
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    AVAssetTrack *videoTrack = [[self.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];

    // get the frame rate from videoSettings, if not set then try to get it from the video track,
    // if not set (mainly when asset is AVComposition) then use the default frame rate of 30
    float trackFrameRate = 0;
    if (self.videoSettings)
    {
        NSDictionary *videoCompressionProperties = [self.videoSettings objectForKey:AVVideoCompressionPropertiesKey];
        if (videoCompressionProperties)
        {
            
            NSNumber *maxKeyFrameInterval = [videoCompressionProperties objectForKey:AVVideoMaxKeyFrameIntervalKey];
            if (maxKeyFrameInterval)
            {
                trackFrameRate = maxKeyFrameInterval.floatValue;
            }
           

        }
    }
    else
    {
        trackFrameRate = [videoTrack nominalFrameRate];
    }

    if (trackFrameRate == 0)
    {
        trackFrameRate = 30;
    }

	videoComposition.frameDuration = CMTimeMake(1, trackFrameRate);
	CGSize targetSize = CGSizeMake([self.videoSettings[AVVideoWidthKey] floatValue], [self.videoSettings[AVVideoHeightKey] floatValue]);
	CGSize naturalSize = [videoTrack naturalSize];
	CGAffineTransform transform = videoTrack.preferredTransform;
	CGFloat videoAngleInDegree  = atan2(transform.b, transform.a) * 180 / M_PI;
	if (videoAngleInDegree == 90 || videoAngleInDegree == -90) {
		CGFloat width = naturalSize.width;
		naturalSize.width = naturalSize.height;
		naturalSize.height = width;
	}
	videoComposition.renderSize = naturalSize;
	// center inside
	{
		float ratio;
		float xratio = targetSize.width / naturalSize.width;
		float yratio = targetSize.height / naturalSize.height;
		ratio = MIN(xratio, yratio);

		float postWidth = naturalSize.width * ratio;
		float postHeight = naturalSize.height * ratio;
		float transx = (targetSize.width - postWidth) / 2;
		float transy = (targetSize.height - postHeight) / 2;

		CGAffineTransform matrix = CGAffineTransformMakeTranslation(transx / xratio, transy / yratio);
		matrix = CGAffineTransformScale(matrix, ratio / xratio, ratio / yratio);
		transform = CGAffineTransformConcat(transform, matrix);
	}

	// Make a "pass through video track" video composition.
	AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
	passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, self.asset.duration);

	AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];

    [passThroughLayer setTransform:transform atTime:kCMTimeZero];

	passThroughInstruction.layerInstructions = @[passThroughLayer];
	videoComposition.instructions = @[passThroughInstruction];

    return videoComposition;
}

- (void)finish
{
    // Synchronized block to ensure we never cancel the writer before calling finishWritingWithCompletionHandler
    if (self.reader.status == AVAssetReaderStatusCancelled || self.writer.status == AVAssetWriterStatusCancelled)
    {
        return;
    }

    if (self.writer.status == AVAssetWriterStatusFailed)
    {
        [self complete];
    }
    else
    {
        [self.writer endSessionAtSourceTime:lastSamplePresentationTime];
        [self.writer finishWritingWithCompletionHandler:^
        {
            [self complete];
        }];
    }
}

- (void)complete
{
    if (self.writer.status == AVAssetWriterStatusFailed || self.writer.status == AVAssetWriterStatusCancelled)
    {
        [NSFileManager.defaultManager removeItemAtURL:self.outputURL error:nil];
    }

    if (self.completionHandler)
    {
        self.completionHandler();
        self.completionHandler = nil;
    }
}

- (NSError *)error
{
    if (_error)
    {
        return _error;
    }
    else
    {
        return self.writer.error ? : self.reader.error;
    }
}

- (AVAssetExportSessionStatus)status
{
    switch (self.writer.status)
    {
        default:
        case AVAssetWriterStatusUnknown:
            return AVAssetExportSessionStatusUnknown;
        case AVAssetWriterStatusWriting:
            return AVAssetExportSessionStatusExporting;
        case AVAssetWriterStatusFailed:
            return AVAssetExportSessionStatusFailed;
        case AVAssetWriterStatusCompleted:
            return AVAssetExportSessionStatusCompleted;
        case AVAssetWriterStatusCancelled:
            return AVAssetExportSessionStatusCancelled;
    }
}

- (void)cancelExport
{
    if (self.inputQueue)
    {
        dispatch_async(self.inputQueue, ^
        {
            [self.writer cancelWriting];
            [self.reader cancelReading];
            [self complete];
            [self reset];
        });
    }
}

- (void)reset
{
    _error = nil;
    self.progress = 0;
    self.reader = nil;
    self.videoOutput = nil;
    self.audioOutput = nil;
    self.writer = nil;
    self.videoInput = nil;
    self.videoPixelBufferAdaptor = nil;
    self.audioInput = nil;
    self.inputQueue = nil;
    self.completionHandler = nil;
}

@end
