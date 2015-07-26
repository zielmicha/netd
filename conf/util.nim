
proc enumTable*[A, B, C](a: openarray[tuple[key: A, val: B]], ret: typedesc[C]): C =
  for item in a:
    result[item.key] = item.val
