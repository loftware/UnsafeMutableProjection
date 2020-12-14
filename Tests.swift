import XCTest
import LoftDataStructures_UnsafeMutableProjection

extension Array {
  /// Returns the address of the first element.
  var baseAddress: UnsafePointer<Element> { withUnsafeBufferPointer { $0.baseAddress! }}
}

/// A type that does projection with simple `get` and `set`.
struct ProjectsWithGetSet {
  var tag = 3
  var content = [1, 2, 3]

  /// A version of `Self` with its `tag` represented as a string.
  struct StringTagged {
    var tag: String
    var content: [Int]
  }

  /// A mutable projection of `self` as `StringTagged`
  var stringTagged: StringTagged {
    get { StringTagged(tag: String(tag), content: content) }
    set { (tag, content) = (Int(newValue.tag)!, newValue.content)}
  }
}

/// A type that does projection with simple `get` and `set` and a naïve `_modify`.
struct ProjectsWithGetSetModify {
  var tag = 3
  var content = [1, 2, 3]

  /// A version of `Self` with its `tag` represented as a string.
  struct StringTagged {
    var tag: String
    var content: [Int]
  }

  /// A mutable projection of `self` as `StringTagged`
  var stringTagged: StringTagged {
    get { StringTagged(tag: String(tag), content: content) }
    set { (tag, content) = (Int(newValue.tag)!, newValue.content)}
    _modify {
      var projection = self.stringTagged
      yield &projection
      self.stringTagged = projection
    }
  }
}

/// A type that does projection with `unsafeMutableProjection`.
struct ProjectsWithUnsafeMutableProjection {
  var tag = 3
  var content = [1, 2, 3]

  /// A version of `Self` with its `tag` represented as a string.
  struct StringTagged {
    var tag: String
    var content: [Int]
  }

  /// A mutable projection of `self` as `StringTagged`
  var stringTagged: StringTagged {
    get { StringTagged(tag: String(tag), content: content) }
    set { (tag, content) = (Int(newValue.tag)!, newValue.content)}
    _modify {
      var (myAddress, projection) = unsafeMutableProjection(destroying: &self) { $0.stringTagged }
      #if !os(Windows)
      defer {
        myAddress.initialize(to: Self(tag: Int(projection.tag)!, content: projection.content))
      }
      #endif
      yield &projection
      #if os(Windows)
      myAddress.initialize(to: Self(tag: Int(projection.tag)!, content: projection.content))
      #endif
    }
  }
}

final class UnsafeMutableProjectionTests: XCTestCase {
  func testGetSet() {
    var a = ProjectsWithGetSet()
    let before = a.content.baseAddress
    a.stringTagged.tag += "3"
    a.stringTagged.content[0] += 1
    let after = a.content.baseAddress
    XCTAssertEqual(a.tag, 33, "error in test type.")
    XCTAssertEqual(a.content, [2, 2, 3], "error in test type.")
    XCTAssertNotEqual(before, after, "Simple get/set accessor unexpectedly didn't trigger CoW.")
  }

  func testGetSetModify() {
    var a = ProjectsWithGetSetModify()
    let before = a.content.baseAddress
    a.stringTagged.tag += "3"
    a.stringTagged.content[0] += 1
    let after = a.content.baseAddress
    XCTAssertEqual(a.tag, 33, "error in test type.")
    XCTAssertEqual(a.content, [2, 2, 3], "error in test type.")
    XCTAssertNotEqual(before, after, "Naïve _modify accessor unexpectedly didn't trigger CoW.")
  }

  func testUnsafeMutableProjection() {
    var a = ProjectsWithUnsafeMutableProjection()
    let before = a.content.baseAddress
    a.stringTagged.tag += "3"
    a.stringTagged.content[0] += 1
    let after = a.content.baseAddress
    XCTAssertEqual(a.tag, 33, "error in test type.")
    XCTAssertEqual(a.content, [2, 2, 3], "error in test type.")
    XCTAssertEqual(before, after, "unsafeMutableProjection use unexpectedly triggered CoW.")
  }
}

// MARK: - Example

/// A type that demonstrates mutable projection.
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

  /// An *efficient* mutable projection of `self` as `StringTagged`
  var stringTagged2: StringTagged {
    get { .init(self) }
    set { self = .init(newValue) }
    
    _modify {
      var (myAddress, projection) 
        = unsafeMutableProjection(destroying: &self) { StringTagged($0) }
      
      #if !os(Windows)
      // `self` was just destroyed! Be sure to re-initialize before exiting.
      defer { myAddress.initialize(to: Self(projection)) }
      #endif
      
      yield &projection
      
      #if os(Windows)
      myAddress.initialize(to: Self(projection))
      #endif
    }
  }
}

/// Test for the example in the README
final class ExampleTests: XCTestCase {
  func testNaive() {
    var a = ProjectableWithStringTag(tag: 3, content: [1, 2, 3])
    let before = a.content.baseAddress
    a.stringTagged.tag += "3"
    a.stringTagged.content[0] += 1
    let after = a.content.baseAddress
    XCTAssertEqual(a.tag, 33, "error in test type.")
    XCTAssertEqual(a.content, [2, 2, 3], "error in test type.")
    XCTAssertNotEqual(before, after, "Simple get/set accessor unexpectedly didn't trigger CoW.")
  }

  func testEfficient() {
    var a = ProjectableWithStringTag(tag: 3, content: [1, 2, 3])
    let before = a.content.baseAddress
    a.stringTagged2.tag += "3"
    a.stringTagged2.content[0] += 1
    let after = a.content.baseAddress
    XCTAssertEqual(a.tag, 33, "error in test type.")
    XCTAssertEqual(a.content, [2, 2, 3], "error in test type.")
    XCTAssertEqual(before, after, "Use of unsafeMutableProjection unexpectedly triggered CoW.")
  }
}

// Local Variables:
// fill-column: 100
// End:
