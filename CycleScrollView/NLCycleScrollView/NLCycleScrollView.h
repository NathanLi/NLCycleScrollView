//
//  NLCycleScrollView.h
//  CycleScrollView
//
//  Created by NathanLi on 14-5-9.
//  Copyright (c) 2014年 NL. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NLCycleScrollViewPage.h"

@protocol NLCycleScrollViewDataSource;
@protocol NLCycleScrollViewDelegate;

@interface NLCycleScrollView : UIScrollView

@property (nonatomic, weak) id<NLCycleScrollViewDelegate> cycleDelegate;
@property (nonatomic, weak) id<NLCycleScrollViewDataSource> dataSource;
@property (nonatomic, readonly) NSUInteger     currentPage;
@property (nonatomic, readonly) NSTimeInterval interval;
@property (nonatomic, readonly) NLCycleScrollViewPage *visiblePage;

- (void)reloadData;
- (void)startAutoPlay;
- (void)startAutoPlayWithInterval:(NSTimeInterval)interval;
- (void)endAutoPlay;
- (BOOL)isAutoPlay;

- (NLCycleScrollViewPage *)dequeueReusablePageWithIdentifier:(NSString *)identifier;

@end

@protocol NLCycleScrollViewDataSource <NSObject>

@required
- (NSUInteger)numberPagesOfCycleScrollView:(NLCycleScrollView *)cycleScrollView;
- (NLCycleScrollViewPage *)cycleScrollView:(NLCycleScrollView *)cycleScroolView pageAtIndex:(NSUInteger)index;

@end

@protocol NLCycleScrollViewDelegate <NSObject>

@end
