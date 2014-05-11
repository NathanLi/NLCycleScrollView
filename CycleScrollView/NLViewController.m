//
//  NLViewController.m
//  CycleScrollView
//
//  Created by NathanLi on 14-5-9.
//  Copyright (c) 2014年 NL. All rights reserved.
//

#import "NLViewController.h"
#import "NLCycleScrollView.h"

#define ARC4RANDOM_MAX	0x100000000

@interface NLViewController () <NLCycleScrollViewDataSource>

@end

@implementation NLViewController

#pragma mark - NLCycleScrollViewDataSource
- (NSUInteger)numberPagesOfCycleScrollView:(NLCycleScrollView *)cycleScrollView {
  return 10;
}

- (NLCycleScrollViewPage *)cycleScrollView:(NLCycleScrollView *)cycleScroolView pageAtIndex:(NSUInteger)index {
  static NSString *identifier = @"NLCycleScrollViewPage";
  NLCycleScrollViewPage *pageView = [cycleScroolView dequeueReusablePageWithIdentifier:identifier];
  if (!pageView) {
    pageView = [[NLCycleScrollViewPage alloc] initWithReuseIdentifier:identifier];
  }
  
  [[pageView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
  
  pageView.backgroundColor = [UIColor colorWithRed: (CGFloat)arc4random()/ARC4RANDOM_MAX
                                             green: (CGFloat)arc4random()/ARC4RANDOM_MAX
                                              blue: (CGFloat)arc4random()/ARC4RANDOM_MAX
                                             alpha: 1.0f];
  UILabel* label = [[UILabel alloc] initWithFrame:self.view.bounds];
  label.text = [NSString stringWithFormat:@"%d",index];
  label.backgroundColor = [UIColor clearColor];
  label.textAlignment = NSTextAlignmentCenter;
  label.font = [UIFont boldSystemFontOfSize:50];
  label.textColor = [UIColor whiteColor];
  [pageView addSubview:label];
  
  return pageView;
}
#pragma mark - Life cycle
- (void)viewDidLoad
{
  [super viewDidLoad];
  NLCycleScrollView *cycleScrollView = [[NLCycleScrollView alloc] initWithFrame:self.view.bounds];
  cycleScrollView.dataSource = self;
  [cycleScrollView startAutoPlayWithInterval:6];
  [self.view addSubview:cycleScrollView];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

@end
