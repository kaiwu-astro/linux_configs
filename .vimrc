syntax on
set mouse=i
set si
set ai
set expandtab
set tabstop=4
set shiftwidth=4
set clipboard+=unnamedplus,autoselect
set copyindent
set pastetoggle=<F3>
set ignorecase
set smartcase
set nu
set ruler
set backspace=indent,eol,start
map Ω :set wrap!<CR> |" MacOS option+z
map <C-l> :set nu!<CR>
map <C-w> :q<CR>
map <C-s> :w<CR>
nnoremap <S-Up> :m-2<CR> |" shift + 上箭头 = 移动当前行到上一行
nnoremap <S-Down> :m+1<CR> |" shift + 下箭头 = 移动当前行到下一行
nnoremap <silent> <C-Left>  zH |" control + 左箭头 = 水平向左移动
nnoremap <silent> <C-Right> zL |" control + 右箭头 = 水平向右移动
map <C-k> d$
map <C-a> ^
map <C-e> $
map <S-z> u
map <S-Left> B
map <S-Right> W
map f w |"MacOS 默认option+左=Esc+f，而vim不支持escape sequence，所以=f，来向左移动一个单词
if &diff
    colorscheme desert
endif
