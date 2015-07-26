import unittest
import conf/preparse
import conf/exceptions

suite "":

  test "simple":
    discard preparse(r"""(
hello world
'foobar sdfs' "bazz\" \\"
)""")

  test "bad brackets":
    expect(ParseError):
      discard preparse(r"adad (asdasda")

    expect(ParseError):
      discard preparse(r"adad (asdasda))")

    expect(ParseError):
      discard preparse(r"adad (asdasda]")

  test "bad tokenization":
    expect(TokenizeError):
      discard preparse(r"aaaa'adsd")
