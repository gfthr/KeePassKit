//
//  KPKNode.m
//  KeePassKit
//
//  Created by Michael Starke on 12.07.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//


#import "KPKNode.h"
#import "KPKNode_Private.h"
#import "KPKDeletedNode.h"
#import "KPKEntry.h"
#import "KPKGroup.h"
#import "KPKGroup_Private.h"
#import "KPKIconTypes.h"
#import "KPKTimeInfo.h"
#import "KPKTimeInfo_Private.h"
#import "KPKTree.h"
#import "KPKTree_Private.h"
#import "KPKMetaData.h"

#import "KPKPair.h"
#import "NSUUID+KPKAdditions.h"

@implementation KPKNode

@dynamic notes;
@dynamic title;
@dynamic minimumVersion;
@dynamic updateTiming;
@dynamic customData;

@synthesize tree = _tree;

+ (NSUInteger)defaultIcon {
  return KPKIconPassword;
}

+ (NSSet *)keyPathsForValuesAffectingHasDefaultIcon {
  return [NSSet setWithArray:@[ NSStringFromSelector(@selector(iconUUID)), NSStringFromSelector(@selector(iconId)) ]];
}

+ (NSSet *)keyPathsForValuesAffectingIcon {
  return [NSSet setWithObject:NSStringFromSelector(@selector(iconUUID))];
}

+ (NSSet *)keyPathsForValuesAffectingTree {
  return [NSSet setWithObject:NSStringFromSelector(@selector(parent))];
}

+ (NSSet *)keyPathsForValuesAffectingParentGroup {
  return [NSSet setWithObject:NSStringFromSelector(@selector(parent))];
}

+ (NSSet *)keyPathsForValuesAffectingCustomData {
  return [NSSet setWithObject:NSStringFromSelector(@selector(mutableCustomData))];
}

- (instancetype)init {
  [self doesNotRecognizeSelector:_cmd];
  self = nil;
  return nil;
}

- (instancetype)initWithUUID:(NSUUID *)uuid {
  [self doesNotRecognizeSelector:_cmd];
  self = nil;
  return self;
}

- (instancetype)copyWithTitle:(NSString *)titleOrNil options:(KPKCopyOptions)options {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (KPKComparsionResult)compareToNode:(KPKNode *)aNode {
  return [self _compareToNode:aNode options:0];
}

- (KPKComparsionResult)_compareToNode:(KPKNode *)aNode options:(KPKNodeCompareOptions)options {
  /* pointing to the same instance */
  if(self == aNode) {
    return KPKComparsionEqual;
  }
  
  /* We do not compare UUIDs as those are supposed to be different for nodes unless they are encoded/decoded */
  NSAssert([aNode isKindOfClass:KPKNode.class], @"Unsupported type for quality test");
  
  /* if UUIDs dont's match, nodes aren't considered equal! */
  if(![self.uuid isEqual:aNode.uuid]) {
    return KPKComparsionDifferent;
  }
  
  if(!(options & KPKNodeCompareIgnoreAccessDateOption)) {
    NSComparisonResult result = [self.timeInfo.accessDate compare:aNode.timeInfo.accessDate];
    if(result != NSOrderedSame) {
      return KPKComparsionDifferent;
    }
  }
  if(!(options & KPKNodeCompareIgnoreModificationDateOption)) {
    NSComparisonResult result = [self.timeInfo.modificationDate compare:aNode.timeInfo.modificationDate];
    if(result != NSOrderedSame) {
      return KPKComparsionDifferent;
    }
  }

  if(![self.mutableCustomData isEqualToDictionary:aNode.mutableCustomData]) {
    return KPKComparsionDifferent;
  }

  BOOL isEqual = (_iconId == aNode->_iconId)
  && (_iconUUID == aNode.iconUUID || [_iconUUID isEqual:aNode->_iconUUID])
  && (self.title == aNode.title || [self.title isEqual:aNode.title])
  && (self.notes == aNode.notes || [self.notes isEqual:aNode.notes]);
  return (isEqual ? KPKComparsionEqual : KPKComparsionDifferent);
}

- (NSString*)description {
  return [NSString stringWithFormat:@"%@\rimage=%ld\rname=%@\r%@]",
          self.class,
          (long)self.iconId,
          self.title,
          self.timeInfo];
}

#pragma mark Properties
- (BOOL)isEditable {
  if(self.tree) {
    return self.tree.isEditable;
  }
  return YES;
}

- (BOOL)hasDefaultIcon {
  /* if we have a custom icon, we are certainly not default */
  if(self.iconUUID) {
    return NO;
  }
  return (self.iconId == [self.class defaultIcon]);
}

- (KPKIcon *)icon {
  return [self.tree.metaData findIcon:self.iconUUID];
}

- (NSUInteger)index {
  if(self.parent) {
    return [self.parent _indexForNode:self];
  }
  return 0;
}

- (BOOL)isTrash {
  return [self.asGroup.uuid isEqual:self.tree.metaData.trashUuid];
}

- (BOOL)isUserTemplateGroup {
  return [self.asGroup.uuid isEqual:self.tree.metaData.entryTemplatesGroupUuid];
}

- (BOOL)isUserTemplate {
  return [self isDecendantOf:self.tree.templates];
}

- (BOOL)isTrashed {
  if(self.isTrash) {
    return NO; // Trash is not trashed
  }
  return [self.tree.trash isAnchestorOf:self];
}

- (NSDictionary<NSString *,NSString *> *)customData {
  return [self.mutableCustomData copy];
}

- (KPKGroup *)rootGroup {
  if(!self.parent) {
    return self.asGroup;
  }
  return self.parent.rootGroup;
}

- (BOOL)isAnchestorOf:(KPKNode *)node {
  if(!node) {
    return NO;
  }
  KPKNode *ancestor = node.parent;
  while(ancestor) {
    if(ancestor == self) {
      return YES;
    }
    ancestor = ancestor.parent;
  }
  return NO;
}

- (BOOL)isDecendantOf:(KPKNode *)node {
  return [node isAnchestorOf:self];
}

- (NSUndoManager *)undoManager {
  return self.tree.undoManager;
}

- (void)setIconId:(NSInteger)iconId {
  [[self.undoManager prepareWithInvocationTarget:self] setIconId:self.iconId];
  [self touchModified];
  _iconId = iconId;
}

- (void)setIconUUID:(NSUUID *)iconUUID {
  [[self.undoManager prepareWithInvocationTarget:self] setIconUUID:self.iconUUID];
  [self touchModified];
  _iconUUID = iconUUID;
}

- (void)setTimeInfo:(KPKTimeInfo *)timeInfo {
  if(self.timeInfo != timeInfo) {
    _timeInfo = [timeInfo copy];
    _timeInfo.node = self;
  }
}

#pragma mark KPKTimerecording
- (void)setUpdateTiming:(BOOL)updateTiming {
  self.timeInfo.updateTiming = updateTiming;
}

- (BOOL)updateTiming {
  return self.timeInfo.updateTiming;
}

- (void)touchModified {
  [self.timeInfo touchModified];
}

- (void)touchAccessed {
  [self.timeInfo touchAccessed];
}

- (void)touchMoved {
  [self.timeInfo touchMoved];
}

- (void)trashOrRemove {
  /* If we do create a trahs group we should also remove it after a undo operation */
  if(self == self.tree.trash) {
    return; // Prevent recursive trashing of trash group
  }
  if(self.tree.metaData.useTrash) {
    [self.undoManager beginUndoGrouping];
  }
  KPKGroup *trash = [self.tree createTrash];
  NSAssert(self.tree.trash == trash, @"Trash should be nil or equal");
  if(trash) {
    [self moveToGroup:trash];
  }
  else {
    [self remove];
  }
  if(trash) {
    [self.undoManager endUndoGrouping];
  }
}

- (void)remove {
  for(KPKGroup *group in self.asGroup.mutableGroups.reverseObjectEnumerator) {
    [group remove];
  }
  for(KPKEntry *entry in self.asGroup.mutableEntries.reverseObjectEnumerator) {
    [entry remove];
  }
  [[self.undoManager prepareWithInvocationTarget:self] addToGroup:self.parent atIndex:self.index];
  NSAssert(nil == self.tree.mutableDeletedObjects[self.uuid], @"Node already registered as deleted!");
  self.tree.mutableDeletedObjects[self.uuid] = [[KPKDeletedNode alloc] initWithNode:self];
  /* keep a strong reference for undo support in the tree */
  NSAssert(nil == self.tree.mutableDeletedNodes[self.uuid], @"Node is already deleted!");
  self.tree.mutableDeletedNodes[self.uuid] = self;
  [self.parent _removeChild:self];
}

- (void)moveToGroup:(KPKGroup *)group {
  [self moveToGroup:group atIndex:NSNotFound];
}

- (void)moveToGroup:(KPKGroup *)group atIndex:(NSUInteger)index {
  /* TODO handle moving accross trees! */
  [[self.undoManager prepareWithInvocationTarget:self] moveToGroup:self.parent atIndex:self.index];
  [self.parent _removeChild:self];
  if(self.tree && group.tree) {
    NSAssert(self.tree == group.tree, @"Moving nodes between trees is not supported. Use -remove and -addToGroup: instead.");
  }
  [group _addChild:self atIndex:index];
  [self touchMoved];
}

- (void)addToGroup:(KPKGroup *)group {
  [self addToGroup:group atIndex:NSNotFound];
}

- (void)addToGroup:(KPKGroup *)group atIndex:(NSUInteger)index {
  /* setup parent relationship to make undo possible */
  self.parent = group;
  [[self.undoManager prepareWithInvocationTarget:self] remove];
  [group _addChild:self atIndex:index];
  /* remove deleted object if we undo a remove */
  self.tree.mutableDeletedObjects[self.uuid] = nil;
  /* clean node store since we now have a strong ref again */
  self.tree.mutableDeletedNodes[self.uuid] = nil;
  [self touchMoved];
}

- (KPKGroup *)asGroup {
  return nil;
}

- (KPKEntry *)asEntry {
  return nil;
}

- (BOOL)_updateFromNode:(KPKNode *)node options:(KPKUpdateOptions)options {
  NSComparisonResult result = [self.timeInfo.modificationDate compare:node.timeInfo.modificationDate];
  if(result == NSOrderedAscending || (options & KPKUpdateOptionIgnoreModificationTime)) {
    self.iconId = node.iconId;
    self.iconUUID = node.iconUUID;
    self.title = node.title;
    self.notes = node.notes;
    self.mutableCustomData = [[NSMutableDictionary alloc] initWithDictionary:node.mutableCustomData copyItems:YES];
    return YES;
  }
  return NO;
}

- (void)removeCustomDataForKey:(NSString *)key {
  if(!key) {
    return;
  }
  NSString *value = self.mutableCustomData[key];
  if(!value) {
    return;
  }
  [[self.undoManager prepareWithInvocationTarget:self] addCustomData:value forKey:key];
  [self removeCustomDataObject:[KPKPair pairWithKey:key value:value]];
}

- (void)addCustomData:(NSString *)value forKey:(NSString *)key {
  if(key && value) {
    [[self.undoManager prepareWithInvocationTarget:self] removeCustomDataForKey:key];
    [self addCustomDataObject:[KPKPair pairWithKey:key value:value]];
  }
}

- (void)clearCustomData {
  for(NSString *key in self.mutableCustomData) {
    [[self.undoManager prepareWithInvocationTarget:self] addCustomData:self.mutableCustomData[key] forKey:key];
  }
  
  NSMutableSet *pairs = [[NSMutableSet alloc] initWithCapacity:self.mutableCustomData.count];
  for(NSString *key in self.mutableCustomData) {
    [pairs addObject:[KPKPair pairWithKey:key value:self.mutableCustomData[key]]];
  }
  [self removeCustomData:pairs];
}

#pragma mark -
#pragma mark KVO


#pragma mark -
#pragma mark Private Extensions
- (instancetype)_init {
  self = [self _initWithUUID:nil];
  return self;
}

- (instancetype)_initWithUUID:(NSUUID *)uuid {
  self = [super init];
  if (self) {
    _uuid = uuid ? [uuid copy] : [[[NSUUID alloc] init] copy];
    self.timeInfo = [[KPKTimeInfo alloc] init];
    _iconId = self.class.defaultIcon;
    _mutableCustomData = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (instancetype)_initWithCoder:(NSCoder *)aDecoder {
  self = [self _init];
  if(self) {
    _uuid = [[aDecoder decodeObjectOfClass:NSUUID.class forKey:NSStringFromSelector(@selector(uuid))] copy];
    _iconId = [aDecoder decodeIntegerForKey:NSStringFromSelector(@selector(iconId))];
    _iconUUID = [[aDecoder decodeObjectOfClass:NSUUID.class forKey:NSStringFromSelector(@selector(iconUUID))] copy];
    /* decode time info at last */
    self.timeInfo = [aDecoder decodeObjectOfClass:KPKTimeInfo.class forKey:NSStringFromSelector(@selector(timeInfo))];
    _mutableCustomData = [aDecoder decodeObjectOfClass:NSMutableDictionary.class forKey:NSStringFromSelector(@selector(mutableCustomData))];
  }
  return self;
}

- (void)_encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.timeInfo forKey:NSStringFromSelector(@selector(timeInfo))];
  [aCoder encodeObject:self.uuid forKey:NSStringFromSelector(@selector(uuid))];
  [aCoder encodeInteger:self.iconId forKey:NSStringFromSelector(@selector(iconId))];
  [aCoder encodeObject:self.iconUUID forKey:NSStringFromSelector(@selector(iconUUID))];
  [aCoder encodeObject:self.mutableCustomData forKey:NSStringFromSelector(@selector(mutableCustomData))];
}

- (instancetype)_copyWithUUID:(NSUUID *)uuid {
  KPKNode *copy = [[self.class alloc] _initWithUUID:uuid];
  copy.iconId = self.iconId;
  copy.iconUUID = self.iconUUID;
  copy.notes = self.notes;
  copy.title = self.title;
  copy.timeInfo = self.timeInfo;
  copy.mutableCustomData = [[NSMutableDictionary alloc] initWithDictionary:self.mutableCustomData copyItems:YES];
  return copy;
}

- (KPKTree *)tree {
  if(self.parent) {
    return self.parent.tree;
  }
  return _tree;
}

- (void)setTree:(KPKTree *)tree {
  if(self.parent) {
    _tree = nil;
    return;
  }
  _tree = tree;
}

- (void)_regenerateUUIDs {
  _uuid = [[[NSUUID alloc] init] copy];
}

- (void)_traverseNodesWithOptions:(KPKNodeTraversalOptions)options block:(void (^)(KPKNode *node))block {
  [self doesNotRecognizeSelector:_cmd];
}

- (void)_traverseNodesWithBlock:(void (^)(KPKNode *))block {
  [self _traverseNodesWithOptions:0 block:block];
}

- (void)addCustomDataObject:(KPKPair *)pair {
  NSAssert(pair.key, @"Custom data key cannot be nil!");
  NSAssert(pair.value, @"Custom data value cannot be nil!");
  self.mutableCustomData[pair.key] = pair.value;
}

- (void)removeCustomDataObject:(KPKPair *)pair {
  [self removeCustomData:[NSSet setWithObject:pair]];
}

- (void)removeCustomData:(NSSet *)setOfPairs {
  for(KPKPair *pair in setOfPairs) {
    NSAssert(pair.key, @"Custom data object key cannot be nil!");
    NSString *value = self.mutableCustomData[pair.key];
    if(![value isEqualToString:pair.value]) {
      NSLog(@"Warning. Expected value for key is %@, but actual value is: %@", pair.value, value);
    }
    self.mutableCustomData[pair.key] = nil;
  }
}

@end
