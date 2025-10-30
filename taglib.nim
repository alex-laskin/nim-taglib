{.experimental.}
{.deadCodeElim: on.}

{.passl: "-ltag_c".}
{.passc: "-ltag_c".}

import os, strutils

type
  FileType* {.size: sizeof(cint).} = enum
    MPEG, OggVorbis, FLAC, MPC,
    OggFlac, WavPack, Speex,
    TrueAudio, MP4, ASF

type
  CFile = pointer
  CTag* = pointer
  CAudioProperties = pointer

{.push importc.}
{.push cdecl.}
proc taglib_set_strings_unicode(unicode: cint)
proc taglib_set_string_management_enabled(management: cint)
proc taglib_free(pointer: pointer)

proc taglib_file_new(filename: cstring): CFile
proc taglib_file_new_type(filename: cstring; `type`: FileType): CFile
proc taglib_file_free(file: CFile)
proc taglib_file_is_valid(file: CFile): cint
proc taglib_file_tag(file: CFile): CTag
proc taglib_file_audioproperties(file: CFile): CAudioProperties
proc taglib_file_save(file: CFile): cint

proc taglib_tag_title(tag: CTag): cstring
proc taglib_tag_artist(tag: CTag): cstring
proc taglib_tag_album(tag: CTag): cstring
proc taglib_tag_comment(tag: CTag): cstring
proc taglib_tag_genre(tag: CTag): cstring
proc taglib_tag_year(tag: CTag): cuint
proc taglib_tag_track(tag: CTag): cuint
proc taglib_tag_set_title(tag: CTag; title: cstring)
proc taglib_tag_set_artist(tag: CTag; artist: cstring)
proc taglib_tag_set_album(tag: CTag; album: cstring)
proc taglib_tag_set_comment(tag: CTag; comment: cstring)
proc taglib_tag_set_genre(tag: CTag; genre: cstring)
proc taglib_tag_set_year(tag: CTag; year: cuint)
proc taglib_tag_set_track(tag: CTag; track: cuint)
proc taglib_tag_free_strings()

proc taglib_audioproperties_length(audioProperties: CAudioProperties): cint
proc taglib_audioproperties_bitrate(audioProperties: CAudioProperties): cint
proc taglib_audioproperties_samplerate(audioProperties: CAudioProperties): cint
proc taglib_audioproperties_channels(audioProperties: CAudioProperties): cint
{.pop.} # cdecl
{.pop.} # importc

taglib_set_strings_unicode(1)

type
  File* = object
    path: string
    cfile: CFile
    tag: CTag
    ap: CAudioProperties
  TaglibError* = object of Exception
  InvalidFileError* = object of TaglibError

proc close*(file: var File) = 
  taglib_tag_free_strings()
  taglib_file_free(file.cfile) 
  file.cfile = cast[CFile](0)
  file.tag = cast[CTag](0)
  file.ap = cast[CAudioProperties](0)

proc `=destroy`*(file: var File) =
  file.close()

proc init_file(path: string, cfile: CFile): File =
  if isNil(cfile):
    raise newException(IOError, "File could not be read.")
  if taglib_file_is_valid(cfile) > 0:
    let tag = taglib_file_tag(cfile)
    let ap = taglib_file_audioproperties(cfile)
    result = File(path: path, cfile: cfile, tag: tag, ap: ap)
  else:
    taglib_file_free(cfile)
    raise newException(InvalidFileError, "Provided file is invalid. Try to select FileType manually.")

proc open*(path: string): File =
  let cfile = taglib_file_new(path)
  init_file(path, cfile)

proc open*(path: string, typ: FileType): File =
  let cfile = taglib_file_new_type(path, typ)
  init_file(path, cfile)

proc open_unknown*(path: string): File =
  for i in FileType.low .. FileType.high:
    try:
      return open(path, FileType(i))
    except:
      discard
  
  raise newException(InvalidFileError, "Provided file is invalid, or file type not supported.")

proc save*(file: File) =
  discard taglib_file_save(file.cfile)


{.push inline.}

proc length*(file: File): int = taglib_audioproperties_length(file.ap)
proc bitrate*(file: File): int = taglib_audioproperties_bitrate(file.ap)
proc samplerate*(file: File): int = taglib_audioproperties_samplerate(file.ap)
proc channels*(file: File): int = taglib_audioproperties_channels(file.ap)

proc title*(file: File): string = $taglib_tag_title(file.tag)
proc `title=`*(file: File, value: string) = taglib_tag_set_title(file.tag, value)

proc artist*(file: File): string = $taglib_tag_artist(file.tag)
proc `artist=`*(file: File, value: string) = taglib_tag_set_artist(file.tag, value)

proc album*(file: File): string = $taglib_tag_album(file.tag)
proc `album=`*(file: File, value: string) = taglib_tag_set_album(file.tag, value)

proc comment*(file: File): string = $taglib_tag_comment(file.tag)
proc `comment=`*(file: File, value: string) = taglib_tag_set_comment(file.tag, value)

proc genre*(file: File): string = $taglib_tag_genre(file.tag)
proc `genre=`*(file: File, value: string) = taglib_tag_set_genre(file.tag, value)

proc year*(file: File): uint = uint(taglib_tag_year(file.tag))
proc `year=`*(file: File, value: uint) = taglib_tag_set_year(file.tag, cuint(value))

proc track*(file: File): uint = uint(taglib_tag_track(file.tag))
proc `track=`*(file: File, value: uint) = taglib_tag_set_track(file.tag, cuint(value))

{.pop.} # inline

proc `$`*(file: File): string =
  "File('$1', '$2 - $3', '$4 - $5')" % [file.artist, $file.year, file.album, $file.track, file.title]
