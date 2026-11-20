//! Shell scripts, Dockerfiles and Makefiles.

use super::{is_digit, is_ident_part, is_ident_start, is_space, Kind, Out, ShellFlavor, Src};

const KEYWORDS: &[&str] = &["if", "then", "else", "elif", "fi", "for", "in", "do", "done", "while", "until", "case", "esac", "function", "select", "return", "break", "continue", "time", "coproc"];
const DECLARATIONS: &[&str] = &["export", "local", "readonly", "declare", "typeset", "unset", "alias"];
const BUILTINS: &[&str] = &["echo", "printf", "cd", "pwd", "source", "eval", "exec", "exit", "test", "read", "set", "shift", "trap", "wait", "kill", "true", "false", "type", "command", "builtin", "let", "mapfile", "getopts"];
const DOCKER: &[&str] = &["FROM", "RUN", "CMD", "LABEL", "MAINTAINER", "EXPOSE", "ENV", "ADD", "COPY", "ENTRYPOINT", "VOLUME", "USER", "WORKDIR", "ARG", "ONBUILD", "STOPSIGNAL", "HEALTHCHECK", "SHELL", "AS"];

pub(crate) fn highlight(src: &Src, out: &mut Out, flavor: ShellFlavor, start: usize, end: usize, _depth: usize) {
    let mut sh = Shell { src, out, flavor, start, command_position: true, heredocs: Vec::new() };
    sh.run(start, end, None);
}

struct Shell<'a, 'b, 'c> {
    src: &'a Src<'b>,
    out: &'c mut Out,
    flavor: ShellFlavor,
    start: usize,
    command_position: bool,
    heredocs: Vec<(String, bool)>,
}

impl Shell<'_, '_, '_> {
    /// Lexes until `end` or, inside `$( … )`, the matching `)`.
    fn run(&mut self, mut i: usize, end: usize, close: Option<u16>) -> usize {
        let src = self.src;
        let mut depth = 0usize;
        while i < end {
            let c = src.at(i);
            if c == '\n' as u16 {
                i += 1;
                self.command_position = true;
                if !self.heredocs.is_empty() { i = self.heredoc_bodies(i, end) }
                if self.flavor == ShellFlavor::Makefile { i = self.makefile_line(i, end) }
                if self.flavor == ShellFlavor::Dockerfile { i = self.dockerfile_line(i, end) }
                continue;
            }
            if i == self.start {
                if self.flavor == ShellFlavor::Makefile { i = self.makefile_line(i, end); continue }
                if self.flavor == ShellFlavor::Dockerfile { i = self.dockerfile_line(i, end); continue }
            }
            if is_space(c) { i += 1; continue }
            if Some(c) == close && depth == 0 { return i }
            match c as u8 {
                b'#' if c < 128 && (i == self.start || is_space(src.at(i - 1)) || src.is(i - 1, ';')) => {
                    let j = src.line_end(i, end);
                    self.out.push(i, j, Kind::Comment);
                    i = j;
                }
                b'"' if c < 128 => i = self.double_quoted(i, end),
                b'\'' if c < 128 => {
                    let j = src.find(i + 1, end, "'").map(|p| p + 1).unwrap_or(end);
                    self.out.push(i, j, Kind::String);
                    i = j;
                    self.command_position = false;
                }
                b'`' if c < 128 => {
                    let j = src.find(i + 1, end, "`").map(|p| p + 1).unwrap_or(end);
                    self.out.push(i, i + 1, Kind::PunctuationSpecial);
                    self.command_position = true;
                    let k = self.run(i + 1, j.saturating_sub(1).max(i + 1), None);
                    self.out.push(k, j, Kind::PunctuationSpecial);
                    i = j;
                }
                b'$' if c < 128 => i = self.variable(i, end),
                b'<' if c < 128 && src.starts(i, "<<") && !src.starts(i, "<<<") => {
                    let mut k = i + 2;
                    let strip = src.is(k, '-');
                    if strip { k += 1 }
                    k = src.skip_blank(k, end);
                    let quoted = src.is(k, '\'') || src.is(k, '"');
                    let w = if quoted { k + 1 } else { k };
                    let we = src.ident_end(w, end, b"-");
                    if we > w {
                        self.out.push(i, i + 2 + usize::from(strip), Kind::Operator);
                        let tag_end = if quoted { we + 1 } else { we };
                        self.out.push(k, tag_end, Kind::Label);
                        self.heredocs.push((src.ascii(w, we), quoted));
                        i = tag_end;
                    } else {
                        self.out.push(i, i + 2, Kind::Operator);
                        i += 2;
                    }
                }
                b'|' | b'&' | b';' | b'(' | b')' | b'{' | b'}' if c < 128 => {
                    let len = if matches!(src.at(i + 1) as u8, b'|' | b'&' | b';') && src.at(i + 1) == c { 2 } else { 1 };
                    if c == '(' as u16 { depth += 1 }
                    if c == ')' as u16 { depth = depth.saturating_sub(1) }
                    let kind = if matches!(c as u8, b'(' | b')' | b'{' | b'}') { Kind::PunctuationBracket } else { Kind::Operator };
                    self.out.push(i, i + len, kind);
                    i += len;
                    self.command_position = true;
                }
                b'>' | b'<' | b'=' | b'!' if c < 128 => { self.out.push(i, i + 1, Kind::Operator); i += 1 }
                b'[' | b']' if c < 128 => { self.out.push(i, i + 1, Kind::PunctuationBracket); i += 1 }
                _ => i = self.word(i, end),
            }
        }
        end
    }

    fn word(&mut self, i: usize, end: usize) -> usize {
        let src = self.src;
        let mut j = i;
        while j < end && !is_space(src.at(j)) && !matches!(src.at(j) as u8, b';' | b'|' | b'&' | b')' | b'(' | b'"' | b'\'' | b'`' | b'$' | b'<' | b'>' | b'{' | b'}') { j += 1 }
        let j = j.max(i + 1);
        let text = src.ascii(i, j);
        // `NAME=value` assignments.
        if let Some(eq) = text.find('=') {
            if eq > 0 && text[..eq].bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_') && is_ident_start(src.at(i)) {
                self.out.push(i, i + eq, Kind::Variable);
                self.out.push(i + eq, i + eq + 1, Kind::Operator);
                self.out.push(i + eq + 1, j, if text[eq + 1..].bytes().all(|b| b.is_ascii_digit()) && eq + 1 < text.len() { Kind::Number } else { Kind::String });
                return j;
            }
        }
        let kind = if KEYWORDS.contains(&text.as_str()) {
            if matches!(text.as_str(), "function") { Kind::KeywordDeclaration } else { Kind::KeywordControl }
        } else if DECLARATIONS.contains(&text.as_str()) {
            Kind::KeywordDeclaration
        } else if text.starts_with('-') && text.len() > 1 && !is_digit(src.at(i + 1)) {
            Kind::Attribute
        } else if self.command_position {
            if BUILTINS.contains(&text.as_str()) { Kind::Function } else if src.is(src.skip_blank(j, end), '(') && src.is(src.skip_blank(j, end) + 1, ')') { Kind::FunctionDefinition } else { Kind::Function }
        } else if text.starts_with('-') && text.len() > 1 && !is_digit(src.at(i + 1)) {
            Kind::Attribute
        } else if text.bytes().all(|b| b.is_ascii_digit()) {
            Kind::Number
        } else {
            Kind::None
        };
        self.out.push(i, j, kind);
        if !matches!(kind, Kind::KeywordControl | Kind::KeywordDeclaration) || matches!(text.as_str(), "in" | "function") {
            self.command_position = false;
        }
        if matches!(text.as_str(), "then" | "do" | "else" | "elif" | "if" | "while" | "until" | "time" | "!") { self.command_position = true }
        j
    }

    fn double_quoted(&mut self, i: usize, end: usize) -> usize {
        let src = self.src;
        let mut seg = i;
        let mut j = i + 1;
        while j < end {
            let c = src.at(j);
            if c == '"' as u16 { j += 1; break }
            if c == '\\' as u16 { self.out.push(seg, j, Kind::String); self.out.push(j, (j + 2).min(end), Kind::StringEscape); j += 2; seg = j; continue }
            if c == '$' as u16 && (is_ident_start(src.at(j + 1)) || matches!(src.at(j + 1) as u8, b'{' | b'(' | b'@' | b'*' | b'#' | b'?' | b'!' | b'0'..=b'9')) {
                self.out.push(seg, j, Kind::String);
                j = self.variable(j, end);
                seg = j;
                continue;
            }
            if c == '`' as u16 {
                self.out.push(seg, j, Kind::String);
                let close = src.find(j + 1, end, "`").map(|p| p + 1).unwrap_or(end);
                self.out.push(j, j + 1, Kind::PunctuationSpecial);
                let saved = self.command_position;
                self.command_position = true;
                let k = self.run(j + 1, close.saturating_sub(1).max(j + 1), None);
                self.command_position = saved;
                self.out.push(k, close, Kind::PunctuationSpecial);
                j = close;
                seg = j;
                continue;
            }
            j += 1;
        }
        let j = j.min(end);
        self.out.push(seg, j, Kind::String);
        self.command_position = false;
        j
    }

    fn variable(&mut self, i: usize, end: usize) -> usize {
        let src = self.src;
        if src.starts(i, "$((") {
            let close = src.find(i + 3, end, "))").map(|p| p + 2).unwrap_or(end);
            self.out.push(i, i + 3, Kind::PunctuationSpecial);
            let mut k = i + 3;
            while k < close.saturating_sub(2) {
                let c = src.at(k);
                if is_digit(c) { let e = src.number_end(k, close); self.out.push(k, e, Kind::Number); k = e }
                else if is_ident_start(c) { let e = src.ident_end(k, close, &[]); self.out.push(k, e, Kind::Variable); k = e }
                else if is_space(c) { k += 1 }
                else { self.out.push(k, k + 1, Kind::Operator); k += 1 }
            }
            self.out.push(close.saturating_sub(2), close, Kind::PunctuationSpecial);
            self.command_position = false;
            return close;
        }
        if src.starts(i, "$(") {
            self.out.push(i, i + 2, Kind::PunctuationSpecial);
            let saved = self.command_position;
            self.command_position = true;
            let k = self.run(i + 2, end, Some(')' as u16));
            self.command_position = saved;
            self.out.push(k, (k + 1).min(end), Kind::PunctuationSpecial);
            self.command_position = false;
            return (k + 1).min(end);
        }
        if src.starts(i, "${") {
            let close = src.find(i + 2, end, "}").map(|p| p + 1).unwrap_or(end);
            self.out.push(i, i + 2, Kind::PunctuationSpecial);
            let name_end = src.ident_end(i + 2, close, &[]);
            self.out.push(i + 2, name_end, Kind::VariableSpecial);
            self.out.push(name_end, close - 1, Kind::Operator);
            self.out.push(close - 1, close, Kind::PunctuationSpecial);
            self.command_position = false;
            return close;
        }
        let j = if is_ident_start(src.at(i + 1)) { src.ident_end(i + 1, end, &[]) } else { (i + 2).min(end) };
        // Makefile `$(VAR)` handled above; `$$` escapes a dollar in recipes.
        self.out.push(i, j, Kind::VariableSpecial);
        self.command_position = false;
        j
    }

    fn heredoc_bodies(&mut self, mut i: usize, end: usize) -> usize {
        let docs = std::mem::take(&mut self.heredocs);
        for (tag, _quoted) in docs {
            let body = i;
            loop {
                if i >= end { self.out.push(body, end, Kind::String); return end }
                let stop = self.src.line_end(i, end);
                let line = self.src.ascii(self.src.skip_blank(i, stop), stop);
                if line == tag {
                    self.out.push(body, i, Kind::String);
                    self.out.push(self.src.skip_blank(i, stop), stop, Kind::Label);
                    i = (stop + 1).min(end);
                    break;
                }
                i = stop + 1;
            }
        }
        i
    }

    fn dockerfile_line(&mut self, i: usize, end: usize) -> usize {
        let src = self.src;
        let k = src.skip_blank(i, end);
        let w = src.ident_end(k, end, &[]);
        let word = src.ascii(k, w).to_ascii_uppercase();
        if DOCKER.contains(&word.as_str()) {
            self.out.push(k, w, Kind::Keyword);
            self.command_position = matches!(word.as_str(), "RUN" | "CMD" | "ENTRYPOINT" | "SHELL" | "HEALTHCHECK");
            if word == "FROM" {
                // `FROM image:tag AS stage`.
                let stop = src.line_end(w, end);
                let img = src.skip_blank(w, stop);
                let img_end = { let mut e = img; while e < stop && !is_space(src.at(e)) { e += 1 } e };
                self.out.push(img, img_end, Kind::String);
                let rest = src.skip_blank(img_end, stop);
                if src.starts_ci(rest, "as ") {
                    self.out.push(rest, rest + 2, Kind::Keyword);
                    let n = src.skip_blank(rest + 2, stop);
                    self.out.push(n, src.ident_end(n, stop, b"-"), Kind::Label);
                }
                return stop;
            }
            if matches!(word.as_str(), "ENV" | "ARG" | "LABEL") {
                let stop = src.line_end(w, end);
                let mut p = src.skip_blank(w, stop);
                while p < stop {
                    let e = src.ident_end(p, stop, b".-");
                    if e == p { break }
                    self.out.push(p, e, Kind::Variable);
                    p = e;
                    if src.is(p, '=') {
                        self.out.push(p, p + 1, Kind::Operator);
                        p += 1;
                        if src.is(p, '"') { p = self.double_quoted(p, stop) } else {
                            let ve = { let mut v = p; while v < stop && !is_space(src.at(v)) { v += 1 } v };
                            self.out.push(p, ve, Kind::String);
                            p = ve;
                        }
                    } else {
                        let ve = src.line_end(p, stop);
                        let v = src.skip_blank(p, ve);
                        self.out.push(v, ve, Kind::String);
                        p = ve;
                    }
                    p = src.skip_blank(p, stop);
                }
                return stop;
            }
            return w;
        }
        i
    }

    fn makefile_line(&mut self, i: usize, end: usize) -> usize {
        let src = self.src;
        // Recipes start with a tab and are shell.
        if src.is(i, '\t') { self.command_position = true; return i + 1 }
        let stop = src.line_end(i, end);
        let k = src.skip_blank(i, stop);
        if src.is(k, '#') { self.out.push(k, stop, Kind::Comment); return stop }
        let w = { let mut e = k; while e < stop && (is_ident_part(src.at(e)) || matches!(src.at(e) as u8, b'.' | b'-' | b'/' | b'%' | b'$' | b'(' | b')' | b' ')) && !src.is(e, ':') && !src.is(e, '=') { e += 1 } e };
        let mut word_end = w;
        while word_end > k && matches!(src.at(word_end - 1), 0x20 | 0x09) { word_end -= 1 }
        let head = src.ascii(k, word_end);
        if matches!(head.split(' ').next().unwrap_or(""), "include" | "-include" | "ifeq" | "ifneq" | "ifdef" | "ifndef" | "else" | "endif" | "define" | "endef" | "export" | "override") {
            let kw_end = src.ident_end(k, stop, b"-");
            self.out.push(k, kw_end, Kind::KeywordControl);
            self.command_position = false;
            return kw_end;
        }
        let after = src.skip_blank(w, stop);
        if src.is(after, ':') && !src.is(after + 1, '=') {
            // `target: prerequisites`.
            self.out.push(k, word_end, Kind::FunctionDefinition);
            self.out.push(after, after + 1, Kind::Operator);
            self.command_position = false;
            return after + 1;
        }
        let op_len = if src.starts(after, ":=") || src.starts(after, "?=") || src.starts(after, "+=") || src.starts(after, "!=") { 2 } else if src.is(after, '=') { 1 } else { 0 };
        if op_len > 0 {
            self.out.push(k, word_end, Kind::Variable);
            self.out.push(after, after + op_len, Kind::Operator);
            self.command_position = false;
            return after + op_len;
        }
        i
    }
}
