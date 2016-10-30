import strutils

proc sanitizePathComponent*(name: string): string =
  if "/" in name or name == "." or name == "..":
    raise newException(ValueError, "invalid name " & name.repr)
  return name
