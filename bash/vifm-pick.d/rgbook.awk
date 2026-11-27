# rgbook's formatter. Its only reader is rgbook-search beside it, which both
# rgbook pickers run (zsh/functions/pdf.zsh, bash/vifm-pick), so moving or
# removing it breaks both.
#
# Input: rg --color=always --line-number output over the papis library's review
# copies, page markers (<page_number>N</page_number>) in the same stream. Output:
# one line per page with a hit, "<path>\t<name>:Page N:<snippet>", the snippet
# cut around the first hit when the line is long. -v sp: the library path with a
# trailing slash, stripped from each path.
{
  first=index($0, ":"); if (!first) next;
  second=index(substr($0, first+1), ":"); if (!second) next;
  path=substr($0, 1, first-1);
  raw=substr($0, first+second+1);
  gsub(/\033\[[0-9;]*m/, "", path);
  if (substr(path, 1, length(sp)) != sp) next;
  path=substr(path, length(sp)+1);
  plain=raw; gsub(/\033\[[0-9;]*m/, "", plain);
  if (plain ~ /^<page_number>[0-9]+<\/page_number>$/) {
    page[path]=plain; sub(/^<page_number>/, "", page[path]);
    sub(/<\/page_number>$/, "", page[path]); next;
  }
  if (!(path in page)) next;
  key=path SUBSEP page[path]; if (seen[key]++) next;
  name=path; sub(/^.*\//, "", name); sub(/\.md$/, ".pdf", name);
  snippet=raw;
  if (length(plain) > 220) {
    start_color=match(raw, /\033\[1m\033\[31m/);
    before=substr(raw, 1, start_color-1);
    gsub(/\033\[[0-9;]*m/, "", before);
    pos=length(before)+1;
    start=pos-50; if (start<1) start=1;
    stop=pos+150; if (stop>length(plain)) stop=length(plain);
    snippet=substr(plain, start, stop-start+1);
    if (start_color) {
      colored=substr(raw, start_color+RLENGTH);
      reset=index(colored, sprintf("%c[0m", 27));
      if (reset) {
        hit=substr(colored, 1, reset-1);
        gsub(/\033\[[0-9;]*m/, "", hit);
        offset=pos-start+1;
        snippet=substr(snippet, 1, offset-1) sprintf("%c[1m%c[31m", 27, 27) hit sprintf("%c[0m", 27) substr(snippet, offset+length(hit));
      }
    }
    if (start>1) snippet="…" snippet;
    if (stop<length(plain)) snippet=snippet "…";
  }
  printf "%s\t%s:\033[32mPage %s\033[0m:%s\n", path, name, page[path], snippet;
}
