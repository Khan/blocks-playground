//
//  KAScratchpadCanvasPath.h
//  Khan Academy
//
//  Created by Andy Matuschak on 7/8/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

/// Represents the data necessary to draw a single segment of an inking path on the canvas.
typedef struct {
	CGPoint point; ///< The center of the path component in canvas coordinate space.
	CGFloat width; ///< The width of the path component in canvas coordinate space.
} KAScratchpadCanvasPathComponent;

/// A collection of `KAScratchpadCanvasPathComponent`s which together describe the geometry of a canvas path.
@interface KAScratchpadCanvasPath : NSObject

/// Initialize a canvas path with an NSData wrapping a C array of `KAScratchpadCanvasPathComponent`s.
- (instancetype)initWithComponentData:(NSData *)componentData hasEndCap:(BOOL)hasEndCap __attribute__((nonnull(1)));

/// A C array of the path's constituent components.
@property (nonatomic, assign, readonly) KAScratchpadCanvasPathComponent *components;

/// The number of elements in `components`.
@property (nonatomic, assign, readonly) NSUInteger componentCount;

/// When YES, the path adds a semicircular cap to the end with most recently added components.
@property (nonatomic, assign, readonly) BOOL hasEndCap;

- (instancetype)init __attribute__((unavailable("Use -initWithComponents:hasEndCap: instead")));

@end
