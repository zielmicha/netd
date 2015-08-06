
proc `&=`[T](a: var seq[T], b: seq[T]) =
  for i in b:
    a.add(i)

proc flatten[T]*(a: seq[seq[T]]): seq[T] =
  result = @[]
  for subseq in a:
    result &= subseq
