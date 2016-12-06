" =============================================================================
" Descriptions:  Provide a function providing folding information for elixir
"           files.
" Maintainer:        Vincent B (twinside@gmail.com)
" Warning: Assume the presence of type signatures on top of your functions to
"          work well.
" Usage:   drop in ~/vimfiles/plugin or ~/.vim/plugin
" Version:     1.2
" Changelog: - 1.2 : Reacting to file type instead of file extension.
"            - 1.1 : Adding foldtext to bet more information.
"            - 1.0 : initial version
" =============================================================================
if exists("g:__ELIXIRFOLD_VIM__")
    finish
endif
let g:__ELIXIRFOLD_VIM__ = 1

" Top level bigdefs
fun! s:ElixirFoldMaster( line ) "{{{
    return a:line =~# '^\s*defp\?'
"      \ || a:line =~# '^type\s'
"      \ || a:line =~# '^newdata\s'
"      \ || a:line =~# '^class\s'
"      \ || a:line =~# '^instance\s'
"      \ || a:line =~  '^[^:]\+\s*::'
endfunction "}}}

" Top Level one line shooters.
fun! s:ElixirSnipGlobal(line) "{{{
    return a:line =~# '^module'
      \ || a:line =~# '^import'
      \ || a:line =~# '^infix[lr]\s'
endfunction "}}}

let s:DEF_PATTERN = '\%(^\s*\)\@<=defp\?\%(:\)\@!\s\+\([^[:space:];#<,()\[\]]\+\)'
let s:DEF_KW_PATTERN = '\%(^\s*\)\@<=defp\?'
let s:END_PATTERN = '\v(^\s*)@<=end'
let s:SPEC_KW_PATTERN = '\%(^\s*\)\@<=@spec'

function! s:ElixirGetSyntaxType(line, col)
  if a:col == -1 " skip synID lookup for not found match
    return 1
  end
"  call synID(a:line, a:col, 1)
"  syntax sync minlines=20 maxlines=150

  return synIDattr(synID(a:line, a:col, 0), "name")
endfunction

"let s:def_positions = []

" The real folding function
fun! ElixirFold( lineNum ) "{{{
  let line = getline( a:lineNum )

  " Beginning of comment
  if line =~ '^\s*#'
    let matchGroup = s:ElixirGetSyntaxType(a:lineNum, 1)
    if matchGroup == 'elixirBlock' || matchGroup == 'elixirGuard' || matchGroup == 'elixirAnonymousFunction' || matchGroup == 'elixirElseBlock'
      return -1
    else
      return 0
    endif
  endif

  let sw_tab = &tabstop

  let specMatchCol = match(line, s:SPEC_KW_PATTERN)
  if specMatchCol > -1
    let prevNum = a:lineNum - 1
    let prevLine = getline(prevNum)
    let specMatchColPrev = match(prevLine, s:SPEC_KW_PATTERN)
    if specMatchColPrev == specMatchCol
      return -1
    endif

    return '>' . (specMatchCol / sw_tab)
  endif

  "let defMatchCol = matchlist(line, s:DEF_PATTERN)
  let defMatchCol = match(line, s:DEF_KW_PATTERN)

  if defMatchCol > -1
    " found a line with function def ZZZ
    
"    let match_position = match(line, s:DEF_KW_PATTERN)
"    let sub_elem = [a:lineNum, match_position, defMatchCol[1]]
"
"    call add(s:def_positions, sub_elem)

    let prevNum = a:lineNum - 1
    let prevLine = getline(prevNum)
    let end_match_position = match(prevLine, s:END_PATTERN)
    if end_match_position == defMatchCol
      return -1
    endif

    let specMatchCol = match(prevLine, s:SPEC_KW_PATTERN)
    if specMatchCol == defMatchCol
      return -1
    endif

    let matchGroup = s:ElixirGetSyntaxType(a:lineNum, defMatchCol+1)

    if matchGroup == 'elixirDefine' || matchGroup == 'elixirModuleDefine'
          \ || matchGroup == 'elixirPrivateDefine'
      return '>' . (defMatchCol / sw_tab)
    endif
  endif


  let defMatchCol = match(line, s:END_PATTERN)

  if defMatchCol > -1
    " skip next comment lines and see if we have defp as next statement
    let nextLineNum = a:lineNum + 1
    let nextLine = getline(nextLineNum)
    while nextLine =~ '^\s*#'
      let nextLineNum = nextLineNum + 1
      let nextLine = getline(nextLineNum)
    endwhile

    let defp_match_position = match(nextLine, s:DEF_PATTERN)
    if defp_match_position == defMatchCol
      return '='
    endif

    let prevNum = a:lineNum - 1
    let prevLine = getline(prevNum)
    let defp_match_position = match(prevLine, s:DEF_PATTERN)
    while prevNum > 0 && (defp_match_position == -1 || defp_match_position > defMatchCol)
      let prevNum = prevNum - 1
      let prevLine = getline(prevNum)
      let defp_match_position = match(prevLine, s:DEF_PATTERN)
    endwhile

    if defp_match_position == defMatchCol
      return '<' . (defMatchCol / sw_tab)
    else
      return -1
    endif
  endif

  return '='
endfunction "}}}

" This function skim over function definitions
" skiping comments line :
" -- ....
" and merging lines without first non space element, to
" catch the full type expression.
fun! ElixirFoldText() "{{{
    let i = v:foldstart
    let retVal = ''
    let began = 0

"    let commentOnlyLine = '^\s*--.*$'
"    let monoLineComment = '\s*--.*$'
"    let nonEmptyLine    = '^\s\+\S'
"    let emptyLine       = '^\s*$'
"    let multilineCommentBegin = '^\s*{-'
"    let multilineCommentEnd = '-}'

    let isMultiLine = 0

    let line = getline(i)

    if line =~ '^\s*@spec'
      let fun_head = substitute(line, "^\\s*@spec\\s*", "", "")

      let retVal = fun_head . ' '
    else
      "let fun_head = substitute(line, "do\s*\%(#.*\)\?$", "", "")
      let fun_head = substitute(line, "do\\s*\\%(#.*\\)\\?$", "", "")
      let fun_head = substitute(fun_head, "^\\s*", "", "")

      let start_match_position = match(fun_head, s:DEF_PATTERN)
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
        let retVal = fun_head . " +" . clauses . " clause"
      elseif clauses > 1
        let retVal = fun_head . " +" . clauses . " clauses"
      else
        let retVal = fun_head
      endif

    endif

    let retVal = v:folddashes . " " . printf("% 3d", (v:foldend - v:foldstart)) . " " . retVal

"    while i <= v:foldend
"
"        if isMultiLine
"            if line =~ multilineCommentEnd
"                let isMultiLine = 0
"                let line = substitute(line, '.*-}', '', '')
"
"                if line =~ emptyLine
"                    let i = i + 1
"                    let line = getline(i)
"                end
"            else
"                let i = i + 1
"                let line = getline(i)
"            end
"        else
"            if line =~ multilineCommentBegin
"                let isMultiLine = 1
"                continue
"            elseif began == 0 && !(line =~ commentOnlyLine)
"                let retVal = substitute(line, monoLineComment, ' ','')
"                let began = 1
"            elseif began != 0 && line =~ nonEmptyLine
"                let tempVal = substitute( line, '\s\+\(.*\)$', ' \1', '' )
"                let retVal = retVal . substitute(tempVal, '\s\+--.*', ' ','')
"            elseif began != 0
"                break
"            endif
"
"            let i = i + 1
"            let line = getline(i)
"        endif
"    endwhile

"    if retVal == ''
"        " We didn't found any meaningfull text
"        return foldtext()
"    endif

    return retVal
endfunction "}}}

fun! s:setElixirFolding() "{{{
    setlocal foldexpr=ElixirFold(v:lnum)
    setlocal foldtext=ElixirFoldText()
    setlocal foldmethod=expr
    setlocal foldcolumn=2
endfunction "}}}

augroup ElixirFold
    au!
    au FileType elixir call s:setElixirFolding()
augroup END

