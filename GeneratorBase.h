//
//  GeneratorBase.h
//  appledoc
//
//  Created by Tomaz Kragelj on 28.5.09.
//  Copyright (C) 2009, Tomaz Kragelj. All rights reserved.
//

#import <Foundation/Foundation.h>

enum TKGeneratorSectionItemTypes
{
	kTKSectionItemInherits,
	kTKSectionItemConforms,
	kTKSectionItemDeclared,
};

enum TKGeneratorMemberTypes
{
	kTKMemberTypeClass,
	kTKMemberTypeInstance,
	kTKMemberTypeProperty,
};

enum TKGeneratorPrototypeTypes
{
	kTKMemberPrototypeValue,
	kTKMemberPrototypeParameter,
};

enum TKGeneratorMemberSectionTypes
{
	kTKMemberSectionParameters,
	kTKMemberSectionExceptions,
};

//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
/** Defines the basics for an output generator.

￼￼Output generators are objects that generate final output files from the intermediate
(cleaned) XML. Each type of supported output is implemented by a concrete subclass.
This class should be treated as abstract base class. It provides the stubs for the
output generation as well as several helper methods that the subclasses can use to
make their job easier.
 
Each concrete subclass can convert two types of files - the index files and object files.
The subclass can only override the methods for generating output that makes sense for the 
implemented output type. The clients send @c generateOutputForIndex:() to generate the
main index file and @c generateOutputForObject:() to generate the documentation for
individual objects.
 
In both cases, there are two options for generating output in the subclass. The first is
to use the default stubs. This means that the subclass should leave the layout and order
of creation to the base class and should override several methods which are sent during
the creation, depending the object that is being generated. The methods which fall into
this category are easily identified by their @c append prefix. This is the most common
and also the simplest way of getting the job done. However it limits the order in which
output elements are generated (of course the subclass can still use this way and generate
intermediate results which it can store to class variables and then use to generate the
complete output at the end of appending). If the subclass requires more control, it can
also override @c outputDataForObject() and/or @c outputDataForIndex() methods and handle 
the data in a completely custom way (@c outputDataForObject() message is sent from
@c generateOutputForObject:() which sets the class properties with the object data, so 
the subclass can use these to make it's life easier. Similarly, @c outputDataForIndex()
is sent from @c generateOutputForIndex()).
 
The class is designed so that the same instance can be re-used for generation of several
objects by simply sending the instance @c generateOutputForObject:() message and/or
@c generateOutputForIndex:() with the required data.
*/
@interface GeneratorBase : NSObject
{
	NSDictionary* objectData;
	NSString* lastUpdated;
}

//////////////////////////////////////////////////////////////////////////////////////////
/// @name Generation entry points
//////////////////////////////////////////////////////////////////////////////////////////

/** Generates the output￼ data from the given object data.

This is the main message that starts the whole generation for the given object. It copies 
the values from the given data to the properties and then sends the receiver 
@c outputDataForObject() message that triggers the object data parsing and in
turn sends the receiver several messages that can be used to convert the data

@param data ￼￼￼￼￼￼An @c NSDictionary that describes the object for which output is generated.
@return Returns the generated @c NSData or @c nil if nothing was generated.
@exception ￼￼￼￼￼NSException Thrown if generation fails or the given @c data is @c nil.
@see outputDataForObject
@see generateOutputForIndex:()
*/
- (NSData*) generateOutputForObject:(NSDictionary*) data;

/** Generates the output￼ data from the given index data.

This is the main message that starts the whole generation for the given index. It copies 
the values from the given data to the properties and then sends the receiver 
@c outputDataForIndex() message that triggers the object data parsing and in
turn sends the receiver several messages that can be used to convert the data

@param data ￼￼￼￼￼￼An @c NSDictionary that describes the object for which output is generated.
@return Returns the generated @c NSData or @c nil if nothing was generated.
@exception ￼￼￼￼￼NSException Thrown if generation fails or the given @c data is @c nil.
@see outputDataForIndex
@see generateOutputForObject:()
*/
- (NSData*) generateOutputForIndex:(NSDictionary*) data;

//////////////////////////////////////////////////////////////////////////////////////////
/// @name Subclass output generation
//////////////////////////////////////////////////////////////////////////////////////////

/** Generates the output data from the data contained in the class properties.￼

This message is sent from @c generateOutputForObject:() after the passed object data is 
stored in the class properties. The concrete subclasses that require full control over the 
generated data, can override this method and return the desired output. If overriden, the 
subclass can get the XML document through the @c objectMarkup property.
 
By default, this will send several higher level messages which can be overriden instead.
The messages are sent in the following order:
- @c appendObjectHeaderToData:()
 
- @c appendObjectInfoHeaderToData:() @a *
- @c appendObjectInfoItemToData:fromItem:index:type:() @a **
- @c appendObjectInfoFooterToData:() @a *
 
- @c appendObjectOverviewToData:fromItem:() @a *

- @c appendObjectTasksHeaderToData:() @a *
- @c appendObjectTaskHeaderToData:fromItem:index:() @a **
- @c appendObjectTaskMemberToData:fromItem:index:() @a **
- @c appendObjectTaskFooterToData:fromItem:index:() @a **
- @c appendObjectTasksFooterToData:() @a *
 
- @c appendObjectMembersHeaderToData:() @a *
- @c appendObjectMemberGroupHeaderToData:type:() @a **
- @c appendObjectMemberToData:fromItem:index:() @a **
- @c appendObjectMemberGroupFooterToData:() @a **
- @c appendObjectMembersFooterToData:() @a *
 
- @c appendObjectFooterToData:()
 
Note that only a subset of above messages may be sent for a particular object, depending
on the object data. Messages marked with @a * are optional, while messages marked with 
@a ** may additionaly be sent multiple times, for each corresponding item once.

@return ￼￼￼￼Returns an autoreleased @c NSData containing generated output.
@exception ￼￼￼￼￼NSException Thrown if generation fails.
@see generateOutputForObject:
@see outputDataForIndex
*/
- (NSData*) outputDataForObject;

/** Generates the output data from the data contained in the class properties.￼

This message is sent from @c generateOutputForObject:() after the passed object data is 
stored in the class properties. The concrete subclasses that require full control over the 
generated data, can override this method and return the desired output. If overriden, the 
subclass can get the XML document through the @c objectMarkup property.
 
By default, this will send several higher level messages which can be overriden instead.
The messages are sent in the following order:
- @c appendObjectHeaderToData:()
 
- @c appendObjectInfoHeaderToData:() @a *
- @c appendObjectInfoItemToData:fromItem:index:type:() @a **
- @c appendObjectInfoFooterToData:() @a *
 
- @c appendObjectOverviewToData:fromItem:() @a *

- @c appendObjectTasksHeaderToData:() @a *
- @c appendObjectTaskHeaderToData:fromItem:index:() @a **
- @c appendObjectTaskMemberToData:fromItem:index:() @a **
- @c appendObjectTaskFooterToData:fromItem:index:() @a **
- @c appendObjectTasksFooterToData:() @a *
 
- @c appendObjectMembersHeaderToData:() @a *
- @c appendObjectMemberGroupHeaderToData:type:() @a **
- @c appendObjectMemberToData:fromItem:index:() @a **
- @c appendObjectMemberGroupFooterToData:() @a **
- @c appendObjectMembersFooterToData:() @a *
 
- @c appendObjectFooterToData:()
 
Note that only a subset of above messages may be sent for a particular object, depending
on the object data. Messages marked with @a * are optional, while messages marked with 
@a ** may additionaly be sent multiple times, for each corresponding item once.

@return ￼￼￼￼Returns an autoreleased @c NSData containing generated output.
@exception ￼￼￼￼￼NSException Thrown if generation fails.
@see generateOutputForIndex:
@see outputDataForObject
*/
- (NSData*) outputDataForIndex;

//////////////////////////////////////////////////////////////////////////////////////////
/// @name Properties
//////////////////////////////////////////////////////////////////////////////////////////

/** Sets or returns the last updated date.￼

Clients should set this value prior to sending @c generateOutputForObject:() 
message. If the value is non @c nil and is not an empty string, the value can be used by 
the concrete generators to indicate the time of the last update.
*/
@property(copy) NSString* lastUpdated;

@end
