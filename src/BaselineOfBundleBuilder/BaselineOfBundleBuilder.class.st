Class {
	#name : 'BaselineOfBundleBuilder',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfBundleBuilder',
	#package : 'BaselineOfBundleBuilder'
}

{ #category : 'baselines' }
BaselineOfBundleBuilder >> baseline: spec [
	<basline>
	
	spec for: #common do: [  
		spec package: 'BundleBuilder' ]
]
