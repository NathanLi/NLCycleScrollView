//
//  NLCycleScrollViewPage.h
//  CycleScrollView
//
//  Created by NathanLi on 14-5-9.
//  Copyright (c) 2014年 NL. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NLCycleScrollViewPage : UIView

/**
 * The identifier used to categorize views into buckets for reuse.
 * Views will be reused when a new view is requested with a matching identifier.
 * If the reuseIdentifier is nil then the class name will be used.
 */
@property (nonatomic, copy) NSString *reuseIdentifier;

- initWithReuseIdentifier:(NSString *)reuseIdentifier;

/**
 * Called immediately after the view has been dequeued from the recycled view pool.
 */
- (void)prepareForReuse;

@end
