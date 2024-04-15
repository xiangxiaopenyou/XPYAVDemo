//
//  XPYMuxerViewController.m
//  XPYAVDemo
//
//  Created by MoMo on 2024/4/12.
//

#import "XPYMuxerViewController.h"
#import <XPYAVKit/XPYAVKit.h>

@interface XPYMuxerViewController ()

@property (nonatomic, strong) XPYMediaReader *reader;

@end

@implementation XPYMuxerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeCustom];
    startButton.frame = CGRectMake(0, 0, 50, 50);
    [startButton setTitle:@"开始" forState:UIControlStateNormal];
    [startButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startButton];
    startButton.center = self.view.center;
    
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"video_test" ofType:@"mp4"]];
    XPYMediaReaderConfig *config = [XPYMediaReaderConfig new];
    config.mediaType = XPYMediaTypeVideo;
    self.reader = [[XPYMediaReader alloc] initWithURL:url config:config];
}

- (void)startAction:(UIButton *)sender {
    [self.reader startWithCompletion:^(BOOL success, NSError * _Nonnull error) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            while (self.reader.hasVideoSampleBuffer) {
                CMSampleBufferRef sampleBuffer = [self.reader copyNextVideoSampleBuffer];
                NSLog(@"🪐🪐%@", @([XPYAVUtils isKeyFrame:sampleBuffer]));
                if (sampleBuffer) {
                    CFRelease(sampleBuffer);
                }
            }
            if (self.reader.status == AVAssetReaderStatusCompleted) {
                NSLog(@"🪐解封完成");
            }
        });
    }];
}

@end
