//
//  FTFetchedDataSource.m
//  FTFountain
//
//  Created by Tobias Kraentzer on 20.08.15.
//  Copyright (c) 2015 Tobias Kräntzer. All rights reserved.
//

#import "FTDataSourceObserver.h"
#import "FTMutableSet.h"

#import "FTFetchedDataSource.h"

@interface FTFetchedDataSource () <FTDataSourceObserver> {
    FTMutableSet *_fetchedObjects;
    NSHashTable *_observers;
}

@end

@implementation FTFetchedDataSource

#pragma mark Life-cycle

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)context
                                      entity:(NSEntityDescription *)entity
                             sortDescriptors:(NSArray *)sortDescriptors
                                   predicate:(NSPredicate *)predicate
{
    self = [super init];
    if (self) {
        _observers = [NSHashTable weakObjectsHashTable];
        _context = context;
        _entity = entity;
        _sortDescriptors = [sortDescriptors copy];
        _predicate = [predicate copy];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(managedObjectContextObjectsDidChange:)
                                                     name:NSManagedObjectContextObjectsDidChangeNotification
                                                   object:_context];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Fetch Objects

- (void)fetchObjectsWithCompletion:(void (^)(BOOL success, NSError *error))completion
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:_entity.name];
    request.predicate = _predicate;

    NSPersistentStoreAsynchronousFetchResultCompletionBlock resultBlock = ^(NSAsynchronousFetchResult *result) {

        for (id<FTDataSourceObserver> observer in self.observers) {
            if ([observer respondsToSelector:@selector(dataSourceWillReset:)]) {
                [observer dataSourceWillReset:self];
            }
        }

        [_fetchedObjects removeObserver:self];

        _fetchedObjects = [[FTMutableSet alloc] initSortDescriptors:self.sortDescriptors];
        [_fetchedObjects addObjectsFromArray:result.finalResult];
        [_fetchedObjects addObserver:self];

        for (id<FTDataSourceObserver> observer in self.observers) {
            if ([observer respondsToSelector:@selector(dataSourceDidReset:)]) {
                [observer dataSourceDidReset:self];
            }
        }

        if (completion) {
            completion(YES, nil);
        }
    };

    NSAsynchronousFetchRequest *asyncRequest = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:request
                                                                                        completionBlock:resultBlock];

    [_context performBlock:^{
        NSError *error = nil;
        NSAsynchronousFetchResult *result = (NSAsynchronousFetchResult *)[_context executeRequest:asyncRequest error:&error];
        if (result == nil) {
            if (completion) {
                completion(NO, error);
            }
        }
    }];
}

#pragma mark Notification Handling

- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification
{
    NSPredicate *entityPredicate = [NSPredicate predicateWithBlock:^BOOL(NSManagedObject *evaluatedObject, NSDictionary<NSString *, id> *_Nullable bindings) {
        return [evaluatedObject.entity isKindOfEntity:self.entity];
    }];

    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSourceWillChange:)]) {
            [observer dataSourceWillChange:self];
        }
    }

    // Deleted Object

    NSSet *deletedObjects = [notification.userInfo[NSDeletedObjectsKey] filteredSetUsingPredicate:entityPredicate];
    [_fetchedObjects minusSet:deletedObjects];

    // Inserted Objects

    NSSet *insertedObjects = [notification.userInfo[NSInsertedObjectsKey] filteredSetUsingPredicate:entityPredicate];
    insertedObjects = [insertedObjects filteredSetUsingPredicate:self.predicate];
    [_fetchedObjects unionSet:insertedObjects];

    // Updates

    NSSet *updatedObjects = [notification.userInfo[NSUpdatedObjectsKey] filteredSetUsingPredicate:entityPredicate];
    NSSet *updatedObjectsToInsert = [updatedObjects filteredSetUsingPredicate:self.predicate];

    NSMutableSet *updatedObjectsToRemove = [updatedObjects mutableCopy];
    [updatedObjectsToRemove minusSet:updatedObjectsToInsert];

    [_fetchedObjects minusSet:updatedObjectsToRemove];
    [_fetchedObjects unionSet:updatedObjectsToInsert];

    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSourceDidChange:)]) {
            [observer dataSourceDidChange:self];
        }
    }
}

#pragma mark FTDataSource

#pragma mark Getting Item and Section Metrics

- (NSUInteger)numberOfSections
{
    return [_fetchedObjects numberOfSections];
}

- (NSUInteger)numberOfItemsInSection:(NSUInteger)section
{
    return [_fetchedObjects numberOfItemsInSection:section];
}

#pragma mark Getting Items and Sections

- (id)sectionItemForSection:(NSUInteger)section
{
    return [_fetchedObjects sectionItemForSection:section];
}

- (id)itemAtIndexPath:(NSIndexPath *)indexPath
{
    return [_fetchedObjects itemAtIndexPath:indexPath];
}

#pragma mark Observer

- (NSArray *)observers
{
    return [_observers allObjects];
}

- (void)addObserver:(id<FTDataSourceObserver>)observer
{
    [_observers addObject:observer];
}

- (void)removeObserver:(id<FTDataSourceObserver>)observer
{
    [_observers removeObject:observer];
}

#pragma mark FTReverseDataSource

#pragma mark Getting Section Indexes

- (NSIndexSet *)sectionsOfSectionItem:(id)sectionItem
{
    return [_fetchedObjects sectionsOfSectionItem:sectionItem];
}

#pragma mark Getting Item Index Paths

- (NSArray *)indexPathsOfItem:(id)item
{
    return [_fetchedObjects indexPathsOfItem:item];
}

#pragma mark FTDataSourceObserver

- (void)dataSourceWillReset:(id<FTDataSource>)dataSource
{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSourceWillReset:)]) {
            [observer dataSourceWillReset:self];
        }
    }
}

- (void)dataSourceDidReset:(id<FTDataSource>)dataSource
{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSourceDidReset:)]) {
            [observer dataSourceDidReset:self];
        }
    }
}

#pragma mark Begin End Updates

- (void)dataSourceWillChange:(id<FTDataSource>)dataSource
{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSourceWillChange:)]) {
            [observer dataSourceWillChange:self];
        }
    }
}

- (void)dataSourceDidChange:(id<FTDataSource>)dataSource
{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSourceDidChange:)]) {
            [observer dataSourceDidChange:self];
        }
    }
}

#pragma mark Manage Sections

- (void)dataSource:(id<FTDataSource>)dataSource didInsertSections:(NSIndexSet *)sections
{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSource:didInsertSections:)]) {
            [observer dataSource:self didInsertSections:sections];
        }
    }
}

- (void)dataSource:(id<FTDataSource>)dataSource didDeleteSections:(NSIndexSet *)sections
{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSource:didDeleteSections:)]) {
            [observer dataSource:self didDeleteSections:sections];
        }
    }
}

- (void)dataSource:(id<FTDataSource>)dataSource didChangeSections:(NSIndexSet *)sections
{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSource:didChangeSections:)]) {
            [observer dataSource:self didChangeSections:sections];
        }
    }
}

- (void)dataSource:(id<FTDataSource>)dataSource didMoveSection:(NSInteger)section toSection:(NSInteger)newSection
{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSource:didMoveSection:toSection:)]) {
            [observer dataSource:self didMoveSection:section toSection:newSection];
        }
    }
}

#pragma mark Manage Items

- (void)dataSource:(id<FTDataSource>)dataSource didInsertItemsAtIndexPaths:(NSArray *)indexPaths

{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSource:didInsertItemsAtIndexPaths:)]) {
            [observer dataSource:self didInsertItemsAtIndexPaths:indexPaths];
        }
    }
}

- (void)dataSource:(id<FTDataSource>)dataSource didDeleteItemsAtIndexPaths:(NSArray *)indexPaths
{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSource:didDeleteItemsAtIndexPaths:)]) {
            [observer dataSource:self didDeleteItemsAtIndexPaths:indexPaths];
        }
    }
}

- (void)dataSource:(id<FTDataSource>)dataSource didChangeItemsAtIndexPaths:(NSArray *)indexPaths
{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSource:didChangeItemsAtIndexPaths:)]) {
            [observer dataSource:self didChangeItemsAtIndexPaths:indexPaths];
        }
    }
}

- (void)dataSource:(id<FTDataSource>)dataSource didMoveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    for (id<FTDataSourceObserver> observer in self.observers) {
        if ([observer respondsToSelector:@selector(dataSource:didMoveItemAtIndexPath:toIndexPath:)]) {
            [observer dataSource:self didMoveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
        }
    }
}

@end
