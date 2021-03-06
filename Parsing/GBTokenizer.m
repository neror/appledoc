//
//  GBTokenizer.m
//  appledoc
//
//  Created by Tomaz Kragelj on 25.7.10.
//  Copyright (C) 2010, Gentle Bytes. All rights reserved.
//

#import "RegexKitLite.h"
#import "PKToken+GBToken.h"
#import "GBSourceInfo.h"
#import "GBComment.h"
#import "GBTokenizer.h"

@interface GBTokenizer ()

- (BOOL)consumeComments;
- (NSString *)commentValueFromString:(NSString *)value;
- (NSArray *)allTokensFromTokenizer:(PKTokenizer *)tokenizer;
@property (retain) NSString *filename;
@property (retain) NSString *input;
@property (retain) NSArray *tokens;
@property (assign) NSUInteger tokenIndex;
@property (retain) NSMutableString *lastCommentBuilder;
@property (retain) NSMutableString *previousCommentBuilder;
@property (retain) GBSourceInfo *lastCommentSourceInfo;
@property (retain) GBSourceInfo *previousCommentSourceInfo;
@property (retain) NSString *singleLineCommentRegex;
@property (retain) NSString *multiLineCommentRegex;
@property (retain) NSString *commentDelimiterRegex;

@end

#pragma mark -

@implementation GBTokenizer

#pragma mark Initialization & disposal

+ (id)tokenizerWithSource:(PKTokenizer *)tokenizer filename:(NSString *)filename {
	return [[[self alloc] initWithSourceTokenizer:tokenizer filename:filename] autorelease];
}

- (id)initWithSourceTokenizer:(PKTokenizer *)tokenizer filename:(NSString *)filename {
	NSParameterAssert(tokenizer != nil);
	NSParameterAssert(filename != nil);
	NSParameterAssert([filename length] > 0);
	GBLogDebug(@"Initializing tokenizer using %@...", tokenizer);
	self = [super init];
	if (self) {
		self.singleLineCommentRegex = @"(?m-s:\\s*///(.*)$)";
		self.multiLineCommentRegex = @"(?s:/\\*\\*(.*)\\*/)";
		self.commentDelimiterRegex = @"^[!@#$%^&*()_=+`~,<.>/?;:'\"-]{3,}$";
		self.tokenIndex = 0;
		self.lastCommentBuilder = [NSMutableString string];
		self.previousCommentBuilder = [NSMutableString string];
		self.filename = [filename lastPathComponent];
		self.input = tokenizer.string;
		self.tokens = [self allTokensFromTokenizer:tokenizer];
		[self consumeComments];
	}
	return self;
}

#pragma mark Tokenizing handling

- (PKToken *)lookahead:(NSUInteger)offset {
	NSUInteger delta = 0;
	NSUInteger counter = 0;
	while (counter <= offset) {
		NSUInteger index = self.tokenIndex + delta;
		if (index >= [self.tokens count]) return [PKToken EOFToken];
		if ([[self.tokens objectAtIndex:index] isComment]) {
			delta++;
			continue;
		}
		delta++;
		counter++;
	}
	return [self.tokens objectAtIndex:self.tokenIndex + delta - 1];
}

- (PKToken *)currentToken {
	if ([self eof]) return [PKToken EOFToken];
	return [self.tokens objectAtIndex:self.tokenIndex];
}

- (void)consume:(NSUInteger)count {
	if (count == 0) return;
	while (count > 0 && ![self eof]) {
		self.tokenIndex++;
		[self consumeComments];
		count--;
	}
}

- (void)consumeTo:(NSString *)end usingBlock:(void (^)(PKToken *token, BOOL *consume, BOOL *stop))block {
	[self consumeFrom:nil to:end usingBlock:block];
}

- (void)consumeFrom:(NSString *)start to:(NSString *)end usingBlock:(void (^)(PKToken *token, BOOL *consume, BOOL *stop))block {	
	// Skip starting token.
	if (start) {
		if (![[self currentToken] matches:start]) return;
		[self consume:1];
	}
	
	// Report all tokens until EOF or ending token is found.
	NSUInteger level = 1;
	BOOL quit = NO;
	while (![self eof]) {
		// Handle multiple hierarchy.
		if (start && [[self currentToken] matches:start]) level++;
		if ([[self currentToken] matches:end]) {
			if (!start) break;
			if (--level == 0) break;
		}

		// Report the token.
		BOOL consume = YES;
		block([self currentToken], &consume, &quit);
		if (consume) [self consume:1];
		if (quit) break;
	}
	
	// Skip ending token if found.
	if ([[self currentToken] matches:end]) [self consume:1];
}

- (BOOL)eof {
	return (self.tokenIndex >= [self.tokens count]);
}

#pragma mark Token information handling

- (GBSourceInfo *)sourceInfoForCurrentToken {
	return [self sourceInfoForToken:[self currentToken]];
}

- (GBSourceInfo *)sourceInfoForToken:(PKToken *)token {
	NSParameterAssert(token != nil);
	NSUInteger lines = [self.input numberOfLinesInRange:NSMakeRange(0, [token offset])];
	return [GBSourceInfo infoWithFilename:self.filename lineNumber:lines];
}

#pragma mark Comments handling

- (BOOL)consumeComments {
	// This method checks if current token is a comment and consumes all comments until non-comment token is detected or EOF reached. The result of the method is that current index is positioned on the first non-comment token. If current token is not comment, the method doesn't do anything, but simply returns NO to indicate it didn't find a comment and therefore it didn't move current token. This is also where we do initial comments handling such as removing starting and ending chars etc.
	self.previousCommentSourceInfo = nil;
	self.lastCommentSourceInfo = nil;
	if ([self eof]) return NO;
	if (![[self currentToken] isComment]) return NO;

	PKToken *startingPreviousToken = nil;
	PKToken *startingLastToken = nil;
	NSUInteger previousSingleLineEndOffset = 0;
	while (![self eof] && [[self currentToken] isComment]) {
		PKToken *token = [self currentToken];
		NSString *value = nil;
		
		// Match single line comments. Note that we can simplify the code with assumption that there's only one single line comment per match. If regex finds more (should never happen though), we simply combine them together. Then we check if the comment is a continuation of previous single liner by testing the string offset. If so we group the values together, otherwise we create a new single line comment. Finally we remember current comment offset to allow grouping of next single line comment. CAUTION: this algorithm won't group comments unless they start at the beginning of the line!
		NSArray *singleLiners = [[token stringValue] componentsMatchedByRegex:self.singleLineCommentRegex capture:1];
		if ([singleLiners count] > 0) {
			value = [NSString string];
			for (NSString *match in singleLiners) value = [value stringByAppendingString:match];
			BOOL isContinuingPreviousSingleLiner = ([token offset] == previousSingleLineEndOffset + 1);
			if (isContinuingPreviousSingleLiner) {
				[self.lastCommentBuilder appendString:@"\n"];
			} else {
				[self.previousCommentBuilder setString:self.lastCommentBuilder];
				startingPreviousToken = startingLastToken;
				[self.lastCommentBuilder setString:@""];
				startingLastToken = token;
			}
			previousSingleLineEndOffset = [token offset] + [[token stringValue] length];
		}
		
		// Match multiple line comments and only process last (in reality we should only have one comment in each mutliline comment token, but let's handle any strange cases graceosly). 
		else {
			NSArray *multiLiners = [[token stringValue] componentsMatchedByRegex:self.multiLineCommentRegex capture:1];
			value = [multiLiners lastObject];
			[self.previousCommentBuilder setString:self.lastCommentBuilder];
			startingPreviousToken = startingLastToken;
			[self.lastCommentBuilder setString:@""];
			startingLastToken = token;
		}
		
		// Append string value to current comment and proceed with next token.
		[self.lastCommentBuilder appendString:value];
		self.tokenIndex++;
	}
	
	if (startingPreviousToken) self.previousCommentSourceInfo = [self sourceInfoForToken:startingPreviousToken];
	if (startingLastToken) self.lastCommentSourceInfo = [self sourceInfoForToken:startingLastToken];
	return YES;
}

- (NSString *)commentValueFromString:(NSString *)value {
	if ([value length] == 0) return nil;
	NSArray *lines = [value componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	NSMutableArray *comments = [NSMutableArray arrayWithCapacity:[lines count]];
	
	// First pass: removes delimiters. We simply detect 3+ delimiter chars in any combination. If removing delimiter yields empty line, discard it.
	[lines enumerateObjectsUsingBlock:^(NSString *line, NSUInteger idx, BOOL *stop) {
		NSString *stripped = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString *delimited = [stripped stringByReplacingOccurrencesOfRegex:self.commentDelimiterRegex withString:@""];
		if ([stripped length] > [delimited length]) {
			if ([delimited length] > 0) [comments addObject:delimited];
			return;
		}
		[comments addObject:line];
	}];
	
	// If all lines start with a *, ignore the prefix. Note that we ignore first line as it can only contain /** and text! We also ignore last line as if it only contains */
	NSString *prefixRegex = @"(?m:^\\s*\\*[ ]*)";
	__block BOOL stripPrefix = ([comments count] > 1);
	if (stripPrefix) {
		[comments enumerateObjectsUsingBlock:^(NSString *line, NSUInteger idx, BOOL *stop) {
			NSString *stripped = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if (idx == [comments count]-1 && [stripped length] == 0) {
				return;
			}
			if (idx > 0 && ![stripped isMatchedByRegex:prefixRegex]) {
				stripPrefix = NO;
				*stop = YES;
			}
		}];
	}
	
	// Finally remove common line prefix and a single prefix space (but leave multiple spaces to properly handle space prefixed example blocks!) and compose all objects into final comment.
	NSCharacterSet *spacesSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
	NSString *spacesPrefixRegex = @"^ {2,}";
	NSString *tabPrefixRegex = @"^\t";
	NSMutableString *result = [NSMutableString stringWithCapacity:[value length]];
	[comments enumerateObjectsUsingBlock:^(NSString *line, NSUInteger idx, BOOL *stop) {
		if (stripPrefix) line = [line stringByReplacingOccurrencesOfRegex:prefixRegex withString:@""];
		if (![line isMatchedByRegex:spacesPrefixRegex] && ![line isMatchedByRegex:tabPrefixRegex]) line = [line stringByTrimmingCharactersInSet:spacesSet];
		[result appendString:line];
		if (idx < [comments count] - 1) [result appendString:@"\n"];
	}];	
	
	// If the result is empty string, return nil, otherwise return the comment string.
	if ([result length] == 0) return nil;
	return result;
}

- (void)resetComments {
	GBLogDebug(@"Resetting comments...");
	[self.lastCommentBuilder setString:@""];
	[self.previousCommentBuilder setString:@""];
}

- (GBComment *)lastComment {
	if ([self.lastCommentBuilder length] == 0) return nil;
	NSString *value = [self commentValueFromString:self.lastCommentBuilder];
	return [GBComment commentWithStringValue:value sourceInfo:self.lastCommentSourceInfo];
}

- (GBComment *)previousComment {
	if ([self.previousCommentBuilder length] == 0) return nil;
	NSString *value = [self commentValueFromString:self.previousCommentBuilder];
	return [GBComment commentWithStringValue:value sourceInfo:self.previousCommentSourceInfo];
}

#pragma mark Helper methods

- (NSArray *)allTokensFromTokenizer:(PKTokenizer *)tokenizer {
	// Return all appledoc comments too, but ignore ordinary C comments!
	BOOL reportsComments = tokenizer.commentState.reportsCommentTokens;
	tokenizer.commentState.reportsCommentTokens = YES;
	NSMutableArray *result = [NSMutableArray array];
	PKToken *token;
	while ((token = [tokenizer nextToken]) != [PKToken EOFToken]) {
		if ([token isComment] && ![token isAppledocComment]) continue;
		[result addObject:token];
	}
	tokenizer.commentState.reportsCommentTokens = reportsComments;
	return result;
}

#pragma mark Properties

@synthesize filename;
@synthesize input;
@synthesize tokens;
@synthesize tokenIndex;
@synthesize lastComment;
@synthesize lastCommentBuilder;
@synthesize lastCommentSourceInfo;
@synthesize previousComment;
@synthesize previousCommentBuilder;
@synthesize previousCommentSourceInfo;
@synthesize singleLineCommentRegex;
@synthesize multiLineCommentRegex;
@synthesize commentDelimiterRegex;

@end
