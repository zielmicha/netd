import tables, osproc, strutils, strtabs, sequtils, os
import iproute


type
  ProcessInfo = ref object
    # metadata
    key: string
    cmd: seq[string]
    env: TableRef[string, string]
    userTag: string
    namespace: NamespaceName
    # runtime
    poked: bool
    processObj: Process

  ProcessManager* = ref object
    processes: Table[string, ProcessInfo]

proc `$`(info: ProcessInfo): string =
  "[$1] key=$2 ns=$3" % [
    info.cmd.map(proc(s:string):string=quoteShellPosix(s)).join(" "),
    $info.key, info.namespace]

proc newProcessManager*(): ProcessManager =
  new(result)
  result.processes = initTable[string, ProcessInfo]()

proc startProcess(info: ProcessInfo) =
  info.poked = true
  echo "(", info.namespace, ") starting ", $info
  let env = newStringTable()
  for p in os.envPairs():
    env[p.key] = p.value
  for k, v in info.env.pairs:
    env[k] = v
  inNamespace info.namespace:
    info.processObj = startProcess(command=info.cmd[0], args=info.cmd[1..^1],
                                   options={poParentStreams, poUsePath},
                                   env=env)

proc terminate(info: ProcessInfo) =
  if info.processObj != nil:
    echo "terminating ", $info
    info.processObj.terminate()
    info.processObj.close()

proc pokeProcess*(self: ProcessManager, key: string, cmd: seq[string],
                  env: openarray[tuple[key, val: string]]= @[],
                  namespace: NamespaceName=RootNamespace, userTag: string=nil) =
  var processInfo: ProcessInfo
  if not self.processes.hasKey(key):
    processInfo = ProcessInfo()
    processInfo.key = key
    self.processes[key] = processInfo
  else:
    processInfo = self.processes[key]

  if processInfo.namespace == namespace and processInfo.cmd == cmd and processInfo.userTag == userTag and processInfo.env == env.newTable:
    if processInfo.processObj != nil and processInfo.processObj.running:
      processInfo.poked = true
    else:
      echo "process ", $processInfo, "has exited"
  else:
    processInfo.terminate()

    processInfo.namespace = namespace
    processInfo.env = env.newTable
    processInfo.cmd = cmd
    processInfo.userTag = userTag
    startProcess(processInfo)

proc teardownNotPoked*(self: ProcessManager) =
  var newProcesses: Table[string, ProcessInfo] = initTable[string, ProcessInfo]()

  for info in self.processes.values:
    if not info.poked:
      info.terminate()
    else:
      info.poked = true
      newProcesses[info.key] = info

  self.processes = newProcesses

proc exit*(self: ProcessManager) =
  for info in self.processes.values:
    info.terminate()
