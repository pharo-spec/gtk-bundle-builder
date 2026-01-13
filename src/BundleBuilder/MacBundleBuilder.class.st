"
Collectes dependences of a dll list that to make a bundle. 

Example: 
--------
```
MacBundleBuilder new
	basePath: '/usr/local/lib';
	baseDLLs: #('libgtk-4.dylib' 'libgtksourceview-5.dylib');
	bundlePath: 'Plugins';
	copyAllDependenciesTo: 'gtk4';
	fixRPathsOn: 'gtk4'.
```
"
Class {
	#name : 'MacBundleBuilder',
	#superclass : 'BundleBuilder',
	#instVars : [
		'bundlePath'
	],
	#category : 'BundleBuilder',
	#package : 'BundleBuilder'
}

{ #category : 'script' }
MacBundleBuilder class >> makeGTK4Bundle [
	<script>

	self new
		basePath: '/usr/local/lib';
		baseDLLs: #('libadwaita-1.0.dylib' 'libgtk-4.1.dylib' 'libgtksourceview-5.0.dylib');
		bundlePath: 'Plugins';
		copyAllDependenciesTo: 'gtk4';
		fixRPathsOn: 'gtk4';
		copyAll: #('/usr/local/share/glib-2.0/schemas/gschemas.compiled') to: 'gtk4'
]

{ #category : 'script' }
MacBundleBuilder class >> makeGTK4BundleARM [
	<script>

	self new
		basePath: '/opt/homebrew/lib';
		baseDLLs: #('libadwaita-1.0.dylib' 'libgtk-4.1.dylib' 'libgtksourceview-5.0.dylib');
		bundlePath: 'Plugins';
		copyAllDependenciesTo: 'gtk4';
		fixRPathsOn: 'gtk4';
		copyAll: #('/opt/homebrew/share/glib-2.0/schemas/gschemas.compiled') to: 'gtk4' 		
]

{ #category : 'accessing' }
MacBundleBuilder >> bundlePath [

	^ bundlePath
]

{ #category : 'accessing' }
MacBundleBuilder >> bundlePath: aString [

	bundlePath := aString
]

{ #category : 'private' }
MacBundleBuilder >> collectNoSystemLibsOf: aDll excluding: aCollection [
	| result |
	
	result := LibC resultOfCommand: 'otool -L ' , aDll.
	^ result lines allButFirst
		  collect: [ :each | ((each trimBoth substrings: ' ') collect: #trimBoth) first ]
		  thenReject: [ :aName | 
				(aCollection includes: aName) 
					or: [ (aName beginsWith: '/System/') 
						or: [ aName beginsWith: '/usr/lib/' ] ] ]
]

{ #category : 'accessing' }
MacBundleBuilder >> copy: fileString withDependenciesTo: destinationString [
	"to be used when working with a single file (e.g. one i just built)"
	| dependencies |

	dependencies := Set new.
	self deepCollectDependenciesOf: fileString into: dependencies.
	
]

{ #category : 'actions' }
MacBundleBuilder >> copyAllDependenciesTo: aDirectory override: overrideBoolean [
	| dependencies origin dest symlinks |
		
	dependencies := self collectAllDependencies collect: [ :each | 
		{ 
			(each substrings: '/') last. 
			(each first = $/ ifTrue: [ each ] ifFalse: [ self basePath, '/', each ]) asFileReference 
		} ].
	origin := self basePath asFileReference.
	dest := aDirectory asFileReference ensureCreateDirectory.

	symlinks := dependencies select: [ :eachTuple | eachTuple second isSymlink ].	
	"remove from list"
	dependencies := dependencies \ symlinks.
	"collect realpaths"
	symlinks := symlinks collect: [ :eachTuple | eachTuple, { self realPathOfSymlink: eachTuple second } ].
	symlinks 
		reject: [ :eachTuple | (dependencies collect: #second) includes: eachTuple third ]
		thenDo: [ :eachTuple | 
			(dependencies := dependencies copyWith: { 
				eachTuple third basename. 
				eachTuple third }) ].

	dependencies
		select: [ :eachTuple | 
			overrideBoolean or: [ (dest / eachTuple first) exists not ]  ]
		thenDo: [ :eachTuple | 
			| dllReference |
			(dest / eachTuple first) ensureDelete.
			dllReference := eachTuple second.
			dllReference copyTo: dest / eachTuple first ].

	symlinks do: [ :eachTuple |
		| names |
		names := eachTuple collect: [ :each | each asFileReference basename ].
		2 to: 1 by: -1 do: [ :index | 
			self 
				makeLinkOf: (names at: index + 1) 
				as: (names at: index) 
				in: dest ] ]
]

{ #category : 'private - actions' }
MacBundleBuilder >> deepCollectDependenciesOf: aDll into: aCollection [
	| libs |

	(aCollection includes: aDll) ifTrue: [ ^ aCollection ].
	aCollection add: aDll.

	libs := self 
		collectNoSystemLibsOf: (self toCPath: aDll) 
		excluding: aCollection.
	
	libs do: [ :eachName |
		self 
			deepCollectDependenciesOf: eachName 
			into: aCollection ].
	
	^  aCollection
]

{ #category : 'actions' }
MacBundleBuilder >> fixRPathsOn: aDirectory [
	| source |
	
	source := aDirectory asFileReference.
	(source filesMatching: '*.dylib')
		reject: [ :each | each isSymlink ]
		thenDo: [ :each | self fixRPathsOnDll: each ]
]

{ #category : 'private' }
MacBundleBuilder >> fixRPathsOnDll: aFileReference [
	| libs result |

	result := LibC resultOfCommand: ('install_name_tool -id @executable_path/Plugins/{1} {2}' format: {
		aFileReference basename.
		aFileReference fullName }).
	result trimBoth ifNotEmpty: [ 
		self error: 'Can''t change @id of ' , aFileReference fullName ].

	libs := self collectNoSystemLibsOf: aFileReference fullName excluding: #().
	libs := libs reject: [ :each | each beginsWith: '@executable_path' ].
	libs 
		collect: [ :each | each asFileReference ] 
		thenDo: [ :each |
			| command |
			
			"change path as it is (full path)"
			command := 'install_name_tool -change {1} @executable_path/{2} {3}' format: {
				each fullName.
				(self toBundlePath: each basename).
				aFileReference fullName }.
			result := LibC resultOfCommand: command.
			result trimBoth ifNotEmpty: [ self error: 'Can''t change @rpath of ' , aFileReference fullName ].
				
			each basename = aFileReference basename ifFalse: [	
				"change path in case it arrives as @rpath"
				command := 'install_name_tool -change @rpath/{1} @executable_path/{2} {3}' format: {
					each basename.
					(self toBundlePath: each basename).
					aFileReference fullName }.
				result := LibC resultOfCommand: command.
				result trimBoth ifNotEmpty: [ self error: 'Can''t change @rpath of ' , aFileReference fullName ] ] ]
]

{ #category : 'private' }
MacBundleBuilder >> makeLinkOf: aName as: destName in: aDirectory [

	| result |
	(aDirectory / destName) exists ifTrue: [ ^ self ].

	result := LibC resultOfCommand: ('cd {1} && ln -s {2} {3}' format: {
				           aDirectory fullName.
				           aName.
				           destName }).

	result trimBoth ifNotEmpty: [ self error: 'Can''t create link: ' , result ]
]

{ #category : 'private' }
MacBundleBuilder >> realPathOfSymlink: aReference [

	^ (LibC resultOfCommand: 'realpath ' , aReference fullName) trimBoth asFileReference
]

{ #category : 'private' }
MacBundleBuilder >> toBundlePath: aString [

	^  self bundlePath
		ifNotNil: [ :aPath | aPath, '/', aString ]
		ifNil: [ aString ]
]

{ #category : 'private' }
MacBundleBuilder >> toCPath: aDll [
	
	aDll first = $/ ifTrue: [ ^ aDll ].
	^  self basePath, '/', ((aDll beginsWith: '@rpath/')
		ifTrue: [ aDll allButFirst: 7 ]
		ifFalse: [ aDll ])
]
