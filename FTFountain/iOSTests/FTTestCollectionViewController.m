//
//  FTTestCollectionViewController.m
//  FTFountain
//
//  Created by Tobias Kraentzer on 13.08.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import "FTFountain.h"
#import "FTFountainiOS.h"

#import "FTTestCollectionViewController.h"

@interface FTTestCollectionViewController () {
    FTCollectionViewAdapter *_adapter;
}

@end

@implementation FTTestCollectionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    _adapter = [[FTCollectionViewAdapter alloc] initWithCollectionView:self.collectionView];
}

@end
