/// Returns `(source, transform(source.pointee))` and destroys `source.pointee`.
///
/// This is a low-level utility for creating mutable projections of values without
/// causing needless copy-on-write.
///
/// Typical usage:
///
///     func f(x: inout X) { // inout means we have exclusive access to `x`.
///       var (xAddress, xFrobnication)
///         = unsafeMutableProjection(destroying: &x) { x.frobnication() }
///
///       // `xFrobnication` is a mutable projection of `x`
///       somethingWith(&xfrobnication) // mutate it
///
///       xAddress.initialize(to: X(defrobnicating: xFrobnication))
///     }
///
public func unsafeMutableProjection<T, U>(
  destroying source: UnsafeMutablePointer<T>, transform: (T)->U
) -> (address: UnsafeMutablePointer<T>, value: U) {
  return (source, transform(source.move()))
}
