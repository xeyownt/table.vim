" Script: table.vim
" Version: 0.1-MPe
"
" Maintainer: Usman Latif Email: latif@techuser.net
" Patch: Michael Peeters Email: peeters-ml1@noekeon.org
" Webpage: http://www.techuser.net
"
" Description:
" This script defines maps for easier editing and alignmnet of tables.
" For usage and installation instructions consult the documentation
" files that came with this script. In case you are missing the
" documentation files, download a complete distribution of the files
" from http://www.techuser.net/files
"
" Patch:
" - Tab in INSERT mode now insert blanks, hence indenting field. This
"   is closer to expectation I think. NORMAL mode still behaves as 
"   usual
" - Add "Table enabled/disabled" message on toggle
" - Use an array of field position. This makes the code clearer and prepare
"   for variable fieldsep in the future
" - Fixed some boundary cases, and make all pos variable 0-based to avoid
"   future bugs.
" - Replace some functions by native vim equivalent
"
" ToDo:
" - Support variable fieldsep specification
" - Use previous line as heading line (auto-heading)
" - Guess fieldsep in a smart way
"   (like align on "  " or on "=" if they are themselves aligned in previous
"    lines)


map <silent> <Leader>tt :call TableToggle()<CR>
map <silent> <Leader>th :call TableHeading()<CR>
map <silent> <Leader>ta :call TableAlign()<CR>

let s:tablemode = 0
let s:heading = ''
let s:fieldsep = ' \{2,}'
let s:headingpos = []

" Function: TableHeading
" Args: None
"
" use current line as the heading line of the table
" current line should be non-empty

func! TableHeading()
    " get heading line and store it in a script variable
    let s:heading = TrimWS(ExpandTabs(getline(".")))

    if !ValidHeading(s:heading)
        return
    endif

    " Extract field stops from heading line
    let s:headingpos = []
    let l:pos = matchend(s:heading,' *')
    while pos >= 0
        call add(s:headingpos,pos)
        let pos = matchend(s:heading,s:fieldsep,pos)
    endwhile

    " map keys to invoke table navigation functions
    call EnableMaps()

    let s:tablemode = 1
endfunc

" Function: ValidHeading
" Args: None
" Return: boolean
"
" returns 1 if heading is valid, i.e., non-whitespace
" returns 0 otherwise

func! ValidHeading(heading)
    " heading line empty ==> invalid heading
    let l:str = a:heading
    if strlen(str) == matchend(str,'^ *')
        return 0
    endif
    return 1
endfunc

" Function: TableToggle
" Args: None
"
" Toggle Table Mode
" Enable/Disable maps for tablemode keys

func! TableToggle()

    if !ValidHeading(s:heading)
        return
    endif

    " enable/disable maps
    if s:tablemode
        call DisableMaps()
    else
        call EnableMaps()
    endif

    " toggle tablemode
    let s:tablemode = !s:tablemode
endfunc

" Function: Enable Maps
" Args: None
"
" Enable maps for tablemode keys

func! EnableMaps()
    nnoremap <silent> <Tab>    :call NextField(0)<CR>
    inoremap <silent> <Tab>    <C-O>:let save_ve=&ve<CR><C-O>:set ve=all<CR><C-O>:call NextField(1)<CR><C-O>:let &ve=save_ve<CR>
    nnoremap <silent> <S-Tab>  :call PrevField()<CR>
    inoremap <silent> <S-Tab>  <C-O>:call PrevField()<CR>
    echo "Table enabled (<Leader>ta to align a selection, <Tab>/<S-Tab> for next/previous fields)"
endfunc

" Function: Disable Maps
" Args: None
"
" Disable maps for tablemode keys

func! DisableMaps()
    nunmap <Tab>
    iunmap <Tab>
    nunmap <S-Tab>
    iunmap <S-Tab>
    echo "Table disabled"
endfunc


" Function: TableAlign
" Args: None
" Description: align the fields of the row with the fields of the heading

func! TableAlign()
    if !s:tablemode
        return
    endif

    let temp = ""
    let linetext = TrimWS(ExpandTabs(getline('.')))
    let linepos = LenWS(linetext,0)
    let idx = 0

    while (idx < len(s:headingpos)) && (linepos >= 0)
        if idx > 0
            " Pad at least our field sep
            let temp = temp . "  "
        endif
        " Pad to next field of heading and add contents of the next text field after that
        let temp = temp . repeat(' ',s:headingpos[idx]-strlen(temp))
        let temp = temp . Getfield(linetext,linepos)

        " Get next position of field in current line
        let linepos = matchend(linetext,s:fieldsep,linepos)
        let idx = idx + 1
    endwhile

    if temp != linetext
        call setline('.',temp)
    endif
endfunc


" Function: PrevField
" Args: None
"
" position the cursor at the start of the prev field position

func! PrevField()
    let pos = col('.') - 1
    let linenum = line('.')

    " Find index of current field
    let idx=0
    while ( idx < len(s:headingpos) ) && ( pos > s:headingpos[idx] )
        let idx = idx + 1
    endwhile

    " Move to previous field (and previous line if necessary)
    let idx = idx - 1
    if idx < 0
        let linenum = linenum - 1
    endif

    " Move the cursor
    if linenum >= 1
        call cursor(linenum,s:headingpos[idx]+1)
    endif
endfunc

" Function: NextField
" Args: curmode
"
" position the cursor at the start of next field position
" pad the current line with spaces if needed when in insertion
" or replace mode

func! NextField(curmode)
    " pos=0 means 1st char (Note that we are in virtual edit mode)
    let l:pos = col('.') - 1
    let l:posnext = NextFieldPos(pos)
    let l:linenum = line('.')

    "If no nextfield on line goto next line
    "append an empty line if in insert/replace mode
    if posnext == -1
        if a:curmode
            call append(linenum,'')
        endif
        let pos = 0
        let linenum = linenum+1
        let posnext = NextFieldPos(-1)
    endif

    let l:linetext = ExpandTabs(getline(linenum))
    if a:curmode
        " Insert blanks
        call setline(linenum,InsertWS(linetext,pos,posnext-pos))
    else
        " Pad if new cursor position is beyond end-of-line
        if strlen(linetext) <= posnext
            let linetext = linetext . repeat(' ',posnext-strlen(linetext) + 1)
            call setline(linenum,linetext)
        endif
    endif

    if linenum > line('$')
        let linenum = line('$')
        let posnext = col('.') - 1
    endif
    call cursor(linenum,posnext + 1)
endfunc


" Function: NextFieldPos
" Args: string,pattern,startposition
"
" returns the position of the end of field in which pos
" is contained (pos is 0-indexed)

func! NextFieldPos(pos)
    let l:idx = 0
    while idx < len(s:headingpos)
        let l:fieldpos = s:headingpos[idx]
        if fieldpos > a:pos
            return fieldpos
        endif
        let idx = idx + 1
    endwhile
    return -1
endfunc


" Function: Getfield
" Args: str, pos
" Description: Extract the text contents of a field from the
" string str, starting at position pos (pos 0-indexed)

func! Getfield(str,pos)
    let endpos = match(a:str,s:fieldsep,a:pos)
    if endpos == -1
        return strpart(a:str,a:pos)
    else
        return strpart(a:str,a:pos,endpos - a:pos)
    endif
endfunc


" Function: InsertWS
" Args: str,pos,count
" Description: Insert count WS at pos in str (pos 0-indexed)

func! InsertWS(str,pos,count)
    return strpart(a:str,0,a:pos) . repeat(' ',a:count) . strpart(a:str,a:pos)
endfunc


" Function: TrimWS
" Args: str
" Description: Trim any WS at the end of the string str

func! TrimWS(str)
    return strpart(a:str,0,match(a:str,' *$'))
endfunc


" Function: LenWS
" Args: str, startpos
" Description: Length of contiguous whitespace starting at
" position startpos in string str

func! LenWS(str,startpos)
    return matchend(a:str,' *',a:startpos) - a:startpos
endfunc


" Function: ExpandTabs
" Args: str
" Return value: string
"
" Expand all tabs in the string to spaces
" according to tabstop value
" TODO: FLAWED. Number of spaces to insert must depend
" on the actual position of the tab character. Moreover
" it should adapt to actual user preferences regarding
" tab stops

func! ExpandTabs(str)
    return substitute(a:str,"\t",repeat(' ',&tabstop),"")
endfunc
