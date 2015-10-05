import conf/defs, conf/parse, conf/ast, conf/exceptions

let baseAdressingCommands* = SuiteDef(commands: @[
  cmd("default_route", emptyArgDef())
])

# Address definition

let addressDefCommands* = SuiteDef(commands: @[])

# Main suite

let mainCommands* = SuiteDef(commands: @[
  cmd("namespace", singleValueArgDef().valueThunk),
])
