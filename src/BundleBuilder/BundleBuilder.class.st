Class {
	#name : 'BundleBuilder',
	#superclass : 'Object',
	#instVars : [
		'basePath',
		'baseDLLs'
	],
	#category : 'BundleBuilder',
	#package : 'BundleBuilder'
}

{ #category : 'accessing' }
BundleBuilder >> baseDLLs [

	^  baseDLLs
]

{ #category : 'accessing' }
BundleBuilder >> baseDLLs: aCollection [ 
	"set DLLs base to syaty the packaging"

	baseDLLs := aCollection
]

{ #category : 'accessing' }
BundleBuilder >> basePath [

	^ basePath
]

{ #category : 'accessing' }
BundleBuilder >> basePath: aPath [

	basePath := aPath
]

{ #category : 'actions' }
BundleBuilder >> collectAllDependencies [

	^ self deepCollectDependenciesOf: self baseDLLs 
]

{ #category : 'actions' }
BundleBuilder >> copyAll: aCollection to: aDirectory [

	aCollection do: [ :each | 
		| origin dest |
		origin := each asFileReference.
		dest := (aDirectory asFileReference ensureCreateDirectory) / origin basename.
		dest ensureDelete.
		origin copyTo: dest ]
]

{ #category : 'actions' }
BundleBuilder >> copyAllDependenciesTo: aDirectory [
	
	self copyAllDependenciesTo: aDirectory override: false
]

{ #category : 'actions' }
BundleBuilder >> copyAllDependenciesTo: aDirectory override: overrideBoolean [

	self subclassResponsibility
]

{ #category : 'private - actions' }
BundleBuilder >> deepCollectDependenciesOf: aCollectionOfDlls [
	| dependences |
	
	dependences := Set new.
	aCollectionOfDlls do: [ :eachDll | 
		dependences := self 
			deepCollectDependenciesOf: eachDll
			into: 	dependences ].
	^  dependences
]

{ #category : 'private - actions' }
BundleBuilder >> deepCollectDependenciesOf: eachDll into: dependences [

	self subclassResponsibility
]
