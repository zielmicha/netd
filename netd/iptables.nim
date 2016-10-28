import netd/core, subprocess, conf/ast, strutils, collections/random, os

include netd/iptablesconfig

type IptablesPlugin* = ref object of Plugin

proc create*(t: typedesc[IptablesPlugin], manager: NetworkManager): IptablesPlugin =
  new(result)
  result.manager = manager

let tables = ["filter", "nat", "mangle", "raw"]
              # ["filter6", "nat6", "mangle6", "raw6"]

method reload(self: IptablesPlugin) =
  for table in tables:
    let is6 = table[^1] == '6'
    let rawName = if is6: table[0..^2] else: table
    let commandPrefix = if is6: "ip6tables" else: "iptables"
    var header: seq[string] = @["*" & rawName]
    var body: seq[string] = @[]

    for line in checkOutput(@[commandPrefix & "-save", "-t", rawName]).splitLines():
      if line.startswith("#") or line.startswith("*") or line == "COMMIT" or line.len == 0:
        continue
      elif line.startswith(":"):
        if not line.startswith(":NETD."):
          header.add(line)
      elif line.startswith("-A "):
        let spl = line.split(" ")
        let tableName = spl[1]
        if tableName.startswith("NETD."):
          continue
        if spl.len > 3 and spl[2] == "-j" and spl[3].startswith("NETD."):
          # inserted by append_to or prepend_to
          continue

        body.add(line)
      else:
        stderr.writeLine("warning: unknown line in iptables-save: " & line)

    for chain in self.manager.config.commandsWithName("iptables"):
      let suite = chain.args[2].suite
      let chainTable = chain.args[0].stringValue
      let chainName = chain.args[1].stringValue
      if chainTable notin tables:
        raise chain.newConfError("invalid table name")
      if chainTable != table:
        continue
      header.add(":NETD." & chainName & " - [0:0]")

      for cmd in suite.commandsWithName("prepend_to"):
        body.insert("-A " & cmd.args[0].stringValue & " -j NETD." & chainName, 0)

      for cmd in suite.commandsWithName("append_to"):
        body.add("-A " & cmd.args[0].stringValue & " -j NETD." & chainName)

      for cmd in suite.commandsWithName("rule"):
        var str = "-A NETD." & chainName
        for arg in cmd.args:
          str &= " " & arg.stringValue
        body.add(str)

    body.add "COMMIT\L"

    let fileName = "/tmp/" & hexUrandom(10)
    let data = (header & body).join("\n")
    writeFile(fileName, data)
    try:
      checkCall(@[commandPrefix & "-restore", fileName])
    except CalledProcessError:
      echo data
      removeFile(fileName)
      raise newException(Exception, "failed to load iptables table " & table)
    removeFile(fileName)
