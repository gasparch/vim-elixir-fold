" =============================================================================
" Descriptions:  Provide a function providing folding information for elixir
"           files. Part of vim-elixir-ide matapackage.
" Maintainer:        Gaspar Chilingarov (gasparch+elixir@gmail.com)
" Warning: Assume the presence of type signatures on top of your functions to
"          work well.
" Usage:   drop in ~/vimfiles/plugin or ~/.vim/plugin
" Version:     1,0
" Changelog: - 1.0 : initial version
" =============================================================================
if exists("g:__ELIXIRFOLD_VIM__")
    finish
endif
let g:__ELIXIRFOLD_VIM__ = 1

" this plugin heavily relies on correct tabstop setting set in elixir file
" if file is edited on different systems with different tabsettings,
" it may not work properly

"set debug=msg,throw
let s:__DEBUG = 0

let s:FOLD_TOGETHER_EXCEPTIONS = 'handle_\%(call\|cast\|info\)'

let s:DEF_PATTERN = '\%(^\s*\)\@<=\(def\%(p\|macro\)\?\%(:\)\@!\s\+[^[:space:];#<,()\[\]]\+\)'
let s:SPEC_KW_PATTERN = '\%(^\s*\)\@<=@spec'

let s:DEF_MULTILINE_ARGS = 1
let s:DEF_MULTILINE_DO = 2
let s:DEF_SINGLELINE_DO = 3

let s:NONEXISTENT_NAME = "..--nonexistent--.."

" RE to match def on single line (see file testre.vim)
" if this RE matches - it is either one liner or mulriliner
" but def arguments list and do statement are on a single line
"
" see tests for better understanding what we can indent
"                                                                                           |-- multiline do ------------|
"                                                                                                           |--when-----|
let s:DEF_ON_ONE_LINE = '\%(^\s*\)\@<=def\%(p\|macro\)\?\%(:\)\@!\s\+\([^[:space:];#<,()\[\]]\+\)\s*\%(\%(\%(([^)]*)\s*\%(\<when\>.*\)\?\)\?\(\%(\<do\>.*\)\)\)\|\%(\%(([^)]*)\s*\%(\<when\>.*\)\?\)\?\s*,\s*\(\<do\>:.*\)\)\|\(([^)]*)\s*\)\)$'
"                          ^space    defp  no:after      ^__func_name______________^        ^args braces

let s:LINE_PARSE = '\v^(\s*)(#|do:|\w+)'

let s:GET_IN_SYNC_PATTERN = '^\s*\%(test\|describe\|def\%(p\|macro\)\?\)\>'

let s:NON_INITIALIZED = -65536
let s:MAX_LOOK_AHEAD = 50

" TODO: make configurable
let s:POWERLINE_SPACE_SYMBOL = 'Ξ'

fun! s:ResetBufferCache(lineNum, foldLevel) "{{{
  "echom "called ResetBufferCache"
  let b:elixirFoldLine = a:lineNum - 1
  let b:elixirStatus = []
  let b:elixirBaseFoldLevel = a:foldLevel
  let b:elixirLastContext = {'name': ''}
endfunction "}}}

fun! s:ResetPositionCache() "{{{
"  echom "called ResetPositionCache"
  " initialize fold decision cache in current buffer
  let b:elixirFoldCache = map(range(1, line('$')+1), s:NON_INITIALIZED)
  let b:elixirFoldCacheTick = s:NON_INITIALIZED
endfunction "}}}

fun! s:InitBufferCache(lineNum) "{{{
  if !exists("b:elixirFoldLine") || a:lineNum == 1
    let z = s:ResetBufferCache(a:lineNum, 0)
  endif
endfunction "}}}

" The real folding function
fun! ElixirFold( lineNum ) "{{{
  " on startup fold-expr can be called twice
  " cache first run results
  if b:elixirFoldCacheTick == b:changedtick
    let cached_value = b:elixirFoldCache[a:lineNum]
    if cached_value != s:NON_INITIALIZED
      return cached_value
    endif
  endif

  call s:InitBufferCache(a:lineNum)

  let inSequence = (b:elixirFoldLine == a:lineNum - 1)

  if inSequence
    let result = s:ElixirFoldProcessLine(a:lineNum, b:elixirBaseFoldLevel)
  else
    let backtrack = s:elixirNeedMoreBacktrack(a:lineNum)

"    echom "working on line" . a:lineNum . " backtrack " . backtrack

    if backtrack
      let b:elixirFoldLine = -999
      return -1
    else
      " we found line with def/etc
      let initialFoldLevel = foldlevel(a:lineNum) - 1
      call s:ResetBufferCache(a:lineNum, initialFoldLevel)
      call s:ResetPositionCache()

      let result = s:ElixirFoldProcessLine(a:lineNum, b:elixirBaseFoldLevel)
      let inSequence = 1
    endif
  endif

"  echom "working on line" . a:lineNum . " in seq " . inSequence . " result " . result
"  echom getline(a:lineNum)

  if inSequence
    let b:elixirFoldLine = a:lineNum

    let b:elixirFoldCache[a:lineNum] = result
    let b:elixirFoldCacheTick = b:changedtick
  else
    let b:elixirFoldLine = -999
  endif

"  if !inSequence
"    let line = getline(a:lineNum)
"    let bf = bufnr('%')
"    echom a:lineNum . " " . result . " " . type(result) . " " . bf . " " . line
"  endif

  return result
endfunction "}}}

fun! s:elixirFoldUnknownLevel() "{{{
  if !empty(b:elixirStatus)
    " we do not want to decide which level we are,
    " but we want to keep current level
    return '='
  else
    " look around and decide some fold level
    return -1
  endif
endfunction "}}}

fun! s:elixirNeedMoreBacktrack(lineNum) "{{{
  let foldLevel = foldlevel(a:lineNum)
  let line = getline(a:lineNum)

"  echom "backtrack decision " . a:lineNum . " re=" . (match(line, s:GET_IN_SYNC_PATTERN)) . " flvl=" . (foldLevel) . " -> " . line

  " backtrack until we find line with def or similar anchor
  return match(line, s:GET_IN_SYNC_PATTERN) == -1 || foldLevel > 1
endfunction "}}}

fun! s:ElixirFoldProcessLine( lineNum, initialFoldLevel ) "{{{
  let line = getline( a:lineNum )

  if empty(line)
    return s:elixirFoldUnknownLevel()
  endif

  let lineStart = matchlist(line, s:LINE_PARSE)

  if empty(lineStart)
    return s:elixirFoldUnknownLevel()
  endif

  let offsetWidth = strlen(lineStart[1])
  let strPrefix = lineStart[2]

  " Beginning of comment
"  if strPrefix == "#"
"    let matchGroup = s:ElixirGetSyntaxType(a:lineNum, 1)
"    if matchGroup == 'elixirBlock' || matchGroup == 'elixirGuard' || matchGroup == 'elixirAnonymousFunction' || matchGroup == 'elixirElseBlock'
"      return -1
"    else
"      return 0
"    endif
"  endif

"  let specMatchCol = match(line, s:SPEC_KW_PATTERN)
"  if specMatchCol > -1
"    let prevNum = a:lineNum - 1
"    let prevLine = getline(prevNum)
"    let specMatchColPrev = match(prevLine, s:SPEC_KW_PATTERN)
"    if specMatchColPrev == specMatchCol
"      return -1
"    endif
"
"    return '>' . (specMatchCol / sw_tab)
"  endif

  if strPrefix =~ '^def\%(p\|macro\)\?\>'
    let defMatch = matchlist(line, s:DEF_PATTERN)
    if len(defMatch) < 2
      let defName = s:NONEXISTENT_NAME
    else
      let defName = defMatch[1]
    endif

    let prefixMatch = matchlist(line, s:DEF_ON_ONE_LINE)
    let mode = -1
    if empty(prefixMatch) && defName != s:NONEXISTENT_NAME
      let mode = s:DEF_MULTILINE_ARGS
    else
      call filter(prefixMatch, 'v:val =~ "^\\(do\\|(\\)"')
      if empty(prefixMatch)
        let mode = s:DEF_SINGLELINE_DO
      endif

      if prefixMatch[0] =~ '^('
        let mode = s:DEF_SINGLELINE_DO
      elseif prefixMatch[0] =~ '^do:'
        let mode = s:DEF_SINGLELINE_DO
      else
        let mode = s:DEF_MULTILINE_DO
      endif
    endif

    if (mode == s:DEF_MULTILINE_ARGS) || (mode == s:DEF_MULTILINE_DO)
      " fun def with do/end block
      call add(b:elixirStatus, [a:lineNum, offsetWidth, strPrefix, defName])

      let foldTogether = b:elixirLastContext['name'] == defName
      let foldTogether = foldTogether && match(defName, s:FOLD_TOGETHER_EXCEPTIONS) == -1

      if foldTogether
        return (a:initialFoldLevel + len(b:elixirStatus))
      else
        return '>' . (a:initialFoldLevel + len(b:elixirStatus))
      endif
    else
      "        echom "one-liner or default definition " . defName
      " fun def one-liner
      let nextDef = s:PatternLookForward(a:lineNum + 1, s:DEF_PATTERN, s:MAX_LOOK_AHEAD)

      " echom "joined nextDef only " . join(nextDef)
      " echom "joined nextDef " . join(nextDef) . " lastName " . defName

      if !empty(nextDef) && nextDef[1] == defName
        let b:elixirLastContext['name'] = defName
        return (a:initialFoldLevel + len(b:elixirStatus) + 1)
      else
        return '<' . (a:initialFoldLevel + len(b:elixirStatus) + 1)
      endif
    endif
  endif

  if strPrefix =~ '^\%(test\|describe\)\>'
    let defName = "ignore test names"
    call add(b:elixirStatus, [a:lineNum, offsetWidth, strPrefix, defName])
    return '>' . (a:initialFoldLevel + len(b:elixirStatus))
  endif

  let isEnd = strPrefix == 'end'
  let isOneLineDo = strPrefix =~ "^do:"
  if isEnd || isOneLineDo
    " check last b:elixirStatus element

    if empty(b:elixirStatus)
      return 0
    endif

    " TODO: b:elixirStatus may be empty!!!! (`end` comes before any `def(p)` are
    " seen)
    let [lastLineNum, lastOffset, lastPrefix, lastName] = b:elixirStatus[-1]

    " for speed considerations we accept as fold only def(p) and end on the
    " same indent level
    if (isEnd && lastOffset == offsetWidth) || (isOneLineDo && lastOffset + &tabstop == offsetWidth)
      unlet b:elixirStatus[-1]

      let nextDef = s:PatternLookForward(a:lineNum + 1, s:DEF_PATTERN, s:MAX_LOOK_AHEAD)

      let b:elixirLastContext['name'] = lastName
      "        echom "joined nextDef only " . join(nextDef)
      "        echom "joined nextDef " . join(nextDef) . " lastName " . lastName

      let foldTogether = !empty(nextDef) && nextDef[1] == lastName
      let foldTogether = foldTogether && match(lastName, s:FOLD_TOGETHER_EXCEPTIONS) == -1

      if foldTogether
        return (a:initialFoldLevel + len(b:elixirStatus) + 1)
      else
        return '<' . (a:initialFoldLevel + len(b:elixirStatus) + 1)
      endif
    else
      return '='
    endif
  endif
  return '='
endfunction "}}}

fun! s:PatternLookForward(lineNum, pattern, maxCheck) "{{{
  let i = 0
  let maxLine = line('$')
  while i < a:maxCheck
    if a:lineNum + i > maxLine
      break
    endif

    let line = getline(a:lineNum + i)
    let lineMatch = matchlist(line, a:pattern)

    if !empty(lineMatch)
      return lineMatch
    end

    let i = i + 1
  endwhile
  return 0
endfunction "}}}

fun! ElixirFoldText() "{{{
    let i = v:foldstart
    let retVal = ''
    let began = 0

    let isMultiLine = 0

    let line = getline(i)

    if line =~ '^\s*@spec\>'
      let fun_head = substitute(line, "^\\s*@spec\\s*", "", "")

      let retVal = fun_head . ' '
    elseif line =~ '^\s*\%(test\|describe\)\>'
      let fun_head = line
      let fun_head = substitute(fun_head, "do\\s*\\%(#.*\\)\\?$", "", "")
      let fun_head = substitute(fun_head, "^\\s*", "", "")

      let retVal = fun_head . ' '
    else
      " function heads
      let fun_head = line
      let start_match_position = match(fun_head, s:DEF_PATTERN)

      let fun_head = substitute(fun_head, "do\\s*\\%(#.*\\)\\?$", "", "")
      let fun_head = substitute(fun_head, "^\\s*", "", "")

      let clauses = 0

      while i < v:foldend
        let i = i + 1
        let line = getline(i)

        let more_match_position = match(line, s:DEF_PATTERN)

        if more_match_position == start_match_position
          let clauses = clauses + 1
        end
      endwhile

      if clauses == 1
        let retVal = fun_head . " " . s:POWERLINE_SPACE_SYMBOL . " +" . clauses . " clause "
      elseif clauses > 1
        let retVal = fun_head . " " . s:POWERLINE_SPACE_SYMBOL . " +" . clauses . " clauses "
      else
        let retVal = fun_head
      endif

    endif

    let retVal = v:folddashes . " " . printf("% 3d", (v:foldend - v:foldstart)) . " " . retVal

    return retVal
endfunction "}}}

fun! s:setElixirFolding() "{{{
    call s:ResetPositionCache()

    setlocal foldexpr=ElixirFold(v:lnum)
    setlocal foldtext=ElixirFoldText()
    setlocal foldmethod=expr
    setlocal foldcolumn=0
endfunction "}}}

augroup ElixirFold
    au!
    au FileType elixir call s:setElixirFolding()
augroup END

