//
//  InputTextViewLight.m
//  qtum wallet
//
//  Created by Никита Федоренко on 19.07.17.
//  Copyright © 2017 PixelPlex. All rights reserved.
//

#import "InputTextViewLight.h"

@implementation InputTextViewLight

#pragma mark - Config

-(void)config {
    
    self.layer.borderColor = [UIColor colorWithRed:220/255. green:223/255. blue:226/255. alpha:1].CGColor;
    self.layer.borderWidth = 1;
    self.textContainerInset = UIEdgeInsetsMake(15, 15, 15, 15);
}

@end
