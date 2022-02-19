if exists('b:current_syntax')
  finish
endif

syn case ignore

syntax match ifactortrackerUnmodifiedStatus '•'
syntax match ifactortrackerModifiedStatus '\v\+'
syntax match ifactortrackerLedger '\v\([^\)]*\)' contains=ifactorTrackerAcceptCount
syntax match ifactortrackerAcceptCount '\v[1-9]\d*\/'he=e-1 nextgroup=ifactortrackerAcceptWithModificationCount contained
syntax match ifactortrackerAcceptWithModificationCount '\v[1-9]\d*\/' nextgroup=ifactortrackerRejectCount
syntax match ifactortrackerRejectCount '\v[1-9]\d*'
syntax match ifactortrackerNullCount '\v0\/' nextgroup=ifactortrackerAcceptWithModificationCount,ifactortrackerRejectCount

let b:current_syntax = 'ifactortracker'
