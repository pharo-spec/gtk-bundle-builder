"
Collectes dependences of a dll list that to make a windonws bundle. 

Example: 
--------
```
WindowsBundleBuilder new
	basePath: 'c:\msys64\clang64\bin';
	baseDLLs: #('libgtk-4-1.dll' 'libgtksourceview-5-0.dll');
	copyAllDependenciesTo: 'gtk4'.
```
"
Class {
	#name : 'WindowsBundleBuilder',
	#superclass : 'BundleBuilder',
	#category : 'BundleBuilder',
	#package : 'BundleBuilder'
}

{ #category : 'script' }
WindowsBundleBuilder class >> makeGTK4Bundle [
	<script>

	self new
	basePath: 'c:\msys64\clang64\bin';
	baseDLLs: #('libgtk-4-1.dll' 'libgtksourceview-5-0.dll');
	copyAllDependenciesTo: 'gtk4'.

]

{ #category : 'private - actions' }
WindowsBundleBuilder >> collectMissingDependenciesOf: aFileReference [
	| result |

	result := LibC resultOfCommand: 'ldd ', aFileReference fullName.
	^  result lines 
		collect: [ :each | (each substrings: '=>') collect: #trimmed ]
		thenSelect: [ :aTuple | aTuple second includesSubstring: 'Not found' ]
]

{ #category : 'actions' }
WindowsBundleBuilder >> copyAllDependenciesTo: aDirectory override: overrideBoolean [
	| dependencies origin dest |
		
	dependencies := self collectAllDependencies.
	origin := self basePath asFileReference.
	dest := aDirectory asFileReference ensureCreateDirectory.

	dependencies 
		select: [ :each | 
			overrideBoolean or: [ (dest / each) exists not ]  ]
		thenDo: [ :each | 
			(dest / each) ensureDelete.
			(origin / each) 
				copyTo: dest / each ]
]

{ #category : 'private - actions' }
WindowsBundleBuilder >> deepCollectDependenciesOf: aDll into: aCollection [
	| result libs |

	(aCollection includes: aDll) ifTrue: [ ^ aCollection ].
	aCollection add: aDll.

	result := LibC resultOfCommand: 'ldd ', (self toCPath: aDll).
	libs := result lines 
		collect: [ :each | (each substrings: '=>') collect: #trimmed ]
		thenReject: [ :aTuple | 
			(aCollection includes: aTuple first) 
			or: [ aTuple second beginsWith: '/c/Windows' ] ].

	libs do: [ :eachTuple |
		self 
			deepCollectDependenciesOf: eachTuple first 
			into: aCollection ].
	
	^  aCollection
]

{ #category : 'private' }
WindowsBundleBuilder >> toCPath: aName [

	^  self basePath, '\', aName
]

{ #category : 'actions' }
WindowsBundleBuilder >> verifyAllDependenciesAt: aDirectory [
	"answer a list of missing dependencies"
	
	^ (aDirectory asFileReference filesMatching: '*.dll')
		flatCollect: [ :each | self collectMissingDependenciesOf: each ]
]
