//
//  KAHashingUtilities.h
//  Khan Academy
//
//  Created by Andy Matuschak on 7/9/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#define KA_HASH_INCORPORATE_NUMERIC(hash, value) do { hash = hash * _KAHashingPrime + value; } while (0)
#define KA_HASH_INCORPORATE_BOOLEAN(hash, value) do { hash = hash * _KAHashingPrime + (value << 16); } while (0)
#define KA_HASH_INCORPORATE_OBJECT(hash, value) do { hash = hash * _KAHashingPrime + [value hash]; } while (0)
#define KA_HASH_INCORPORATE_NSARRAY(hash, array) do { for (id obj in array) { KA_HASH_INCORPORATE_OBJECT(hash, obj); } } while (0) // (NSArray's implementation of "hash" is just its length, which is not what you want when making a value type)

/// Not to be used outside KAHashingUtilities.h.
static const NSUInteger _KAHashingPrime = 31;