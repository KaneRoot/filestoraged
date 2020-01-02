require "option_parser"
require "ipc"
require "json"

require "../common/colors"
require "../common/filestorage.cr"

require "./context.cr"
require "./handlers.cr"

# TODO: if the user is disconnected, we should ask him if it still want to process
#       for old requests.
#
# Example: the user is on a web page, the connection is broken for some reason.
#          The user can still browse the website, change page and discard what
#          he was doing. Regardless of the result. With or without finishing to
#          upload or download its files.

# TODO:
# * elegantly handling errors
# * store the file, /files/userid/UID.bin for example: /files/1002/UID.bin
# * metadata should be in a dodb
#   /storage/partitions/by_uid/UID.json -> content:
#     data: /files/uid/UID.bin (storing raw files)
#     uid: 1002
#     name: "The File About Things"
#     size: 1500
#     tags: thing1 thing2
# * authd integration
# * knowing which parts of the files are still to be sent
# * rights
# * quotas

require "./cli.cr" 
require "./main-loop.cr"
