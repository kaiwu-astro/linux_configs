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
set smartcase
set nu
set ruler
set backspace=indent,eol,start
map Ω :set wrap!<CR> |" MacOS option+z
map <C-l> :set nu!<CR>
map <C-w> :q<CR>
map <C-s> :w<CR>
nnoremap <S-Up> :m-2<CR>
nnoremap <S-Down> :m+1<CR>
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
