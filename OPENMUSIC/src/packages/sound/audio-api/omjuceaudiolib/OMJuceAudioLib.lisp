(in-package :om)

(defpackage :juce)

;(fli:register-module 
; "OMJuceAudioLib" 
; :real-name "/Users/bouche/Documents/GIT/om7/OPENMUSIC/resources/lib/mac/OMJuceAudioLib.dylib"
; :connection-style :immediate)

(push :omjuceaudiolib *features*)

(in-package :juce)

;;;==============================================
;;  PLAYER
;;;==============================================

(cffi:defcfun ("OpenAudioPlayer" OpenAudioPlayer) :pointer (inchannels :int) (outchannels :int) (samplerate :int))

;(openaudioplayer 2 2 44100)

(cffi:defcfun ("CloseAudioPlayer" CloseAudioPlayer) :void (player :pointer))

;;;==============================================
;;  BUFFER
;;;==============================================

(cffi:defcfun ("MakeBufferPointer" MakeBufferPointer) :pointer (buffer :pointer) (channels :int) (size :int) (sr :int))

(cffi:defcfun ("FreeBufferPointer" FreeBufferPointer) :void (buffer :pointer))

(cffi:defcfun ("PlayBuffer" PlayBuffer) :void (player :pointer) (buffer :pointer))

(cffi:defcfun ("PauseBuffer" PauseBuffer) :void (player :pointer) (buffer :pointer))

(cffi:defcfun ("StopBuffer" StopBuffer) :void (player :pointer) (buffer :pointer))

(cffi:defcfun ("SetPosBuffer" SetPosBuffer) :void (buffer :pointer) (pos :long))

(cffi:defcfun ("GetPosBuffer" GetPosBuffer) :long (buffer :pointer))

(cffi:defcfun ("LoopBuffer" LoopBuffer) :void (buffer :pointer) (looper :boolean))

;;;==============================================
;;  FILE
;;;==============================================

(cffi:defcfun ("MakeFilePointer" MakeFilePointer) :pointer (file :pointer) (channels :int) (size :int) (sr :int))

(cffi:defcfun ("FreeFilePointer" FreeFilePointer) :void (file :pointer))

(cffi:defcfun ("PlayFile" PlayFile) :void (player :pointer) (file :pointer))

(cffi:defcfun ("PauseFile" PauseFile) :void (player :pointer) (file :pointer))

(cffi:defcfun ("StopFile" StopFile) :void (player :pointer) (file :pointer))

(cffi:defcfun ("SetPosFile" SetPosFile) :void (file :pointer) (pos :long))

(cffi:defcfun ("GetPosFile" GetPosFile) :long (file :pointer))

;(cffi:defcfun ("LoopFile" LoopFile) :void (file :pointer) (looper :boolean))