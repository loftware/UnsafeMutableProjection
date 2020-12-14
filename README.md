# `unsafeMutableProjection(destroying:_:)`

One function that can help you efficiently create a “mutable projection” of a
value without inducing CoW.

A “mutable projection” is a copy of the value, or part of the value, in a
different form that can be mutated in-place (e.g. via `mutating` method calls or
being passed `inout`); when the projection is mutated, the changes are reflected
in the original value.  For example:

```swift
/// A type that can be mutably projected as a related type.
struct ProjectableWithStringTag {
  var tag: Int
  var content: [Int]

  /// Creates an instance with the given stored properties.
  init(tag: Int, content: [Int]) { (self.tag, self.content) = (tag, content) }

  /// A version of `Self` with its `tag` represented as a string.
  struct StringTagged {
    /// Creates an instance corresponding to `x`.
    init(_ x: ProjectableWithStringTag) {
      (tag, content) = (String(x.tag), x.content)
    }
    var tag: String
    var content: [Int]
  }

  /// Creates an instance corresponding to `s`.
  ///
  /// - Precondition: `s.tag` is the string representation of an integer.
  init(_ s: StringTagged) {
    (tag, content) = (Int(s.tag)!, s.content)
  }
  
  
  /// A mutable projection of `self` as `StringTagged`
  var stringTagged: StringTagged {
    get { .init(self) }
    set { self = .init(newValue) }
  }
}
```

If we take an instance `x` of `ProjectableWithStringTag`, project out its
`stringTagged` property, and mutate it as follows, 

```swift
x.stringTagged.content[0] += 1
```

`x.content[0]` will have been incremented, but a needless copy-on-write of the
`content` array will occur.

If instead we rewrite the property, adding this `_modify` clause, no
copy-on-write will occur:

```swift
  /// An *efficient* mutable projection of `self` as `StringTagged`
  var stringTagged: StringTagged {
    get { .init(self) }
    set { self = .init(newValue) }
    
    _modify {
      var (myAddress, projection) 
        = unsafeMutableProjection(destroying: &self) { StringTagged($0) }
      
      // `self` was just destroyed! Be sure to re-initialize before exiting.
      defer { myAddress.initialize(to: Self(projection)) }
      
      yield &projection
    }
  }
```


