# This program opens Zoom meetings from a predefined domain and linking codes to names.
import os, strutils, system

type
  class = tuple
    names: seq[string]
    code: string

  classgroup = tuple
    domain: string
    indClasses: seq[class]

  # The "*" makes it visible to other modules
  BadFormatInClassesfileException* = object of CatchableError
  NoFileException* = object of CatchableError
  ClassNotFoundException* = object of CatchableError


# Creates a link to the zoom in the domain passed and with the code given.    
proc createLink(domain: string, code: string) : string =
  result = "zoommtg://" & domain & "/join?confno=" & code

# Different commands for the different shells in OS's
when system.hostOS == "windows":
  proc callLink(link: string) =
    let command : string = "start " & link
    discard execShellCmd( command )
elif system.hostOS == "macosx":
  proc callLink(link: string) =
    let command : string = "open " & link
    discard execShellCmd( command )


# Returns a class tuple with its names and code from a line of text.
proc getIndClassFromLine(nextLine: string): class =
  let lineWords = nextLine.split(" ")
  if len(lineWords) < 2:
    raise BadFormatInClassesfileException.newException("Missing options, found " & $lineWords.len() & " words, expected at least two")
  
  var nameOptions : seq[string] = @[]
  for i in 0..len(lineWords)-2:
    var nextWord = lineWords[i].toLower()
    if nextWord.isEmptyOrWhitespace: continue
    nameOptions.add nextWord
  result = (names: nameOptions, code: lineWords[lineWords.len-1] )


# Takes the file with the codes and names for the classes,
# it is read as "className1 className2 className3 code"
proc readClassgroup(path: string) : classgroup =
  if not fileExists path:
    raise NoFileException.newException("File " & $path & " was not found.")

  let file = open(path)
  defer: file.close()

  result.domain = splitFile(path).name
  let firstLine = file.readLine().toLower()

  if contains(firstLine, "domain") and contains(firstLine, '='):
    result.domain = firstLine.split("=")[1].strip()
  else:
    result.indClasses.add getIndClassFromLine(firstLine)

  for line in file.lines:
    result.indClasses.add getIndClassFromLine(line)

proc findClassGroups(className: string, classGroups: seq[classgroup]): tuple [domain: string, code: string] =
  for group in items(classGroups):
    for indvClass in items(group.indClasses):
      if indvClass.names.contains(className):
        return (domain: group.domain, code: indvClass.code)
  raise ClassNotFoundException.newException("Class " & className & " not found in registered classes.")

proc printClassGroup(classgroup: classgroup) =
    echo "Classes:\n" & "Domain: " & classgroup.domain
    for individualClass in classgroup.indClasses:
      echo "\nCode: ", individualClass.code, "\nNames: ", individualClass.names

when isMainModule:
  var someClassGroups : seq[classgroup] = @[]
  for fileName in items(["./test", "./test2"]):
    try:
      someClassGroups.add readClassgroup(fileName)
    
    except BadFormatInClassesfileException as badFormat:
      echo badFormat.msg
    except NoFileException as NFE:
      echo NFE.msg & '\n'

  if paramCount() > 0:
    for i in 1 .. paramCount():
      if paramStr(i) == "--showClasses":
        for classG in items(someClassGroups):
          classG.printClassGroup
      break
  
  system.write(stdout, "Zoom Room to open (name or code): ")
  var classSelection = readLine(stdin).strip()
  try:
    var domainWithCode = findClassGroups(classSelection, someClassGroups)
    callLink(createLink(domainWithCode.domain, domainWithCode.code))
  except ClassNotFoundException as CNFE:
    echo "Class not foundc"
