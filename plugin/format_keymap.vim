" format-keymap.vim - Format a ZMK keymap layer to align keys by column

function! s:SplitIntoColumns(line) abort
  let l:trimmed = substitute(a:line, '^\s*\|\s*$', '', 'g')
  if l:trimmed ==# ''
    return []
  endif
  return split(l:trimmed, '\s\{2,}')
endfunction

function! s:FindMaxColsRowIdx(parsed_rows) abort
  let l:max_cols = 0
  let l:max_idx = 0
  let l:idx = 0
  while l:idx < len(a:parsed_rows)
    let l:num_cols = len(a:parsed_rows[l:idx])
    if l:num_cols > l:max_cols
      let l:max_cols = l:num_cols
      let l:max_idx = l:idx
    endif
    let l:idx += 1
  endwhile
  return l:max_idx
endfunction

function! s:MapPreMaxPositions(num_cols, max_cols) abort
  let l:half = a:num_cols / 2
  let l:positions = []
  let l:col_idx = 0
  while l:col_idx < a:num_cols
    if l:col_idx < l:half
      call add(l:positions, l:col_idx)
    else
      call add(l:positions, a:max_cols - a:num_cols + l:col_idx)
    endif
    let l:col_idx += 1
  endwhile
  return l:positions
endfunction

function! s:MapPostMaxPositions(num_cols, max_cols, center_cols) abort
  let l:left_boundary = (a:max_cols - a:center_cols) / 2
  let l:side_cols = (a:num_cols - a:center_cols) / 2
  let l:positions = []

  let l:col_idx = 0
  while l:col_idx < l:side_cols
    call add(l:positions, l:left_boundary - 1 - l:side_cols + l:col_idx)
    let l:col_idx += 1
  endwhile

  let l:col_idx = 0
  while l:col_idx < a:center_cols
    call add(l:positions, l:left_boundary + l:col_idx)
    let l:col_idx += 1
  endwhile

  let l:col_idx = 0
  while l:col_idx < l:side_cols
    call add(l:positions, l:left_boundary + a:center_cols + 1 + l:col_idx)
    let l:col_idx += 1
  endwhile

  return l:positions
endfunction

function! s:ComputeColumnWidths(parsed_rows, max_cols, max_cols_row_idx, center_cols) abort
  let l:widths = repeat([0], a:max_cols)
  let l:row_idx = 0
  while l:row_idx < len(a:parsed_rows)
    let l:row = a:parsed_rows[l:row_idx]
    let l:num_cols = len(l:row)
    if l:num_cols == 0
      let l:row_idx += 1
      continue
    endif

    if l:row_idx < a:max_cols_row_idx
      let l:positions = s:MapPreMaxPositions(l:num_cols, a:max_cols)
    elseif l:num_cols == a:max_cols
      let l:positions = range(a:max_cols)
    else
      let l:positions = s:MapPostMaxPositions(l:num_cols, a:max_cols, a:center_cols)
    endif

    let l:col_idx = 0
    while l:col_idx < l:num_cols
      let l:pos = l:positions[l:col_idx]
      let l:content_width = strwidth(l:row[l:col_idx])
      if l:content_width > l:widths[l:pos]
        let l:widths[l:pos] = l:content_width
      endif
      let l:col_idx += 1
    endwhile

    let l:row_idx += 1
  endwhile
  return l:widths
endfunction

function! s:PadLeft(str, width) abort
  let l:content_width = strwidth(a:str)
  if l:content_width >= a:width
    return a:str
  endif
  return repeat(' ', a:width - l:content_width) . a:str
endfunction

function! s:FormatRow(columns, positions, widths, max_cols) abort
  let l:cells = repeat([''], a:max_cols)
  let l:col_idx = 0
  while l:col_idx < len(a:columns)
    let l:pos = a:positions[l:col_idx]
    let l:cells[l:pos] = a:columns[l:col_idx]
    let l:col_idx += 1
  endwhile

  let l:padded = []
  let l:pos = 0
  while l:pos < a:max_cols
    call add(l:padded, s:PadLeft(l:cells[l:pos], a:widths[l:pos]))
    let l:pos += 1
  endwhile

  let l:result = join(l:padded, '  ')
  return substitute(l:result, '\s*$', '', '')
endfunction

function! s:FormatKeymap(line1, line2) abort
  let l:lines = getline(a:line1, a:line2)
  let l:parsed_rows = map(copy(l:lines), {_, line -> s:SplitIntoColumns(line)})

  let l:max_cols = 0
  for l:row in l:parsed_rows
    let l:num_cols = len(l:row)
    if l:num_cols > l:max_cols
      let l:max_cols = l:num_cols
    endif
    if l:num_cols > 0 && l:num_cols % 2 != 0
      echoerr 'FormatKeymap: Row has odd number of columns (' . l:num_cols . '): ' . join(l:row, ' | ')
      return
    endif
  endfor

  if l:max_cols == 0
    return
  endif

  let l:max_cols_row_idx = s:FindMaxColsRowIdx(l:parsed_rows)

  let l:center_cols = 0
  if l:max_cols_row_idx > 0
    let l:prev_row_cols = len(l:parsed_rows[l:max_cols_row_idx - 1])
    if l:prev_row_cols > 0
      let l:center_cols = l:max_cols - l:prev_row_cols
    endif
  endif

  let l:widths = s:ComputeColumnWidths(l:parsed_rows, l:max_cols, l:max_cols_row_idx, l:center_cols)

  let l:output_lines = []
  let l:row_idx = 0
  while l:row_idx < len(l:parsed_rows)
    let l:row = l:parsed_rows[l:row_idx]
    if len(l:row) == 0
      call add(l:output_lines, '')
    else
      if l:row_idx < l:max_cols_row_idx
        let l:positions = s:MapPreMaxPositions(len(l:row), l:max_cols)
      elseif len(l:row) == l:max_cols
        let l:positions = range(l:max_cols)
      else
        let l:positions = s:MapPostMaxPositions(len(l:row), l:max_cols, l:center_cols)
      endif
      call add(l:output_lines, s:FormatRow(l:row, l:positions, l:widths, l:max_cols))
    endif
    let l:row_idx += 1
  endwhile

  call setline(a:line1, l:output_lines)
endfunction

command! -range FormatKeymap call s:FormatKeymap(<line1>, <line2>)
