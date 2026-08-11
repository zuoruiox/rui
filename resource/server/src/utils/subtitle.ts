// 字幕解析工具 - 支持 SRT/VTT 格式

export interface SubtitleCue {
  index: number;
  startTime: number; // 秒
  endTime: number;   // 秒
  startTimeStr: string;
  endTimeStr: string;
  text: string;
}

// 解析 SRT 时间格式 "00:01:23,456" -> 秒
function parseSrtTime(timeStr: string): number {
  const parts = timeStr.trim().split(':');
  if (parts.length !== 3) return 0;
  const [h, m, sMs] = parts;
  const [s, ms] = sMs.replace(',', '.').split('.');
  return parseInt(h) * 3600 + parseInt(m) * 60 + parseInt(s) + (parseInt(ms || '0') / 1000);
}

// 解析 VTT 时间格式 "00:01:23.456" -> 秒
function parseVttTime(timeStr: string): number {
  const parts = timeStr.trim().split(':');
  if (parts.length === 2) {
    // MM:SS.mmm
    const [m, sMs] = parts;
    const [s, ms] = sMs.split('.');
    return parseInt(m) * 60 + parseInt(s) + (parseInt(ms || '0') / 1000);
  }
  if (parts.length === 3) {
    const [h, m, sMs] = parts;
    const [s, ms] = sMs.split('.');
    return parseInt(h) * 3600 + parseInt(m) * 60 + parseInt(s) + (parseInt(ms || '0') / 1000);
  }
  return 0;
}

// 秒 -> SRT 时间格式
export function formatSrtTime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  const ms = Math.floor((seconds % 1) * 1000);
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')},${String(ms).padStart(3, '0')}`;
}

// 秒 -> VTT 时间格式
export function formatVttTime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  const ms = Math.floor((seconds % 1) * 1000);
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}.${String(ms).padStart(3, '0')}`;
}

// 解析 SRT 字幕
export function parseSRT(content: string): SubtitleCue[] {
  const cues: SubtitleCue[] = [];
  const blocks = content.replace(/\r\n/g, '\n').split(/\n\n+/);

  for (const block of blocks) {
    const lines = block.trim().split('\n').filter(l => l.trim());
    if (lines.length < 2) continue;

    let idx = 0;
    let index = 0;

    // 第一行可能是序号
    if (/^\d+$/.test(lines[0].trim())) {
      index = parseInt(lines[0].trim());
      idx = 1;
    }

    // 时间行
    const timeLine = lines[idx];
    if (!timeLine || !timeLine.includes('-->')) continue;

    const [startStr, endStr] = timeLine.split('-->').map(s => s.trim());
    const startTime = parseSrtTime(startStr);
    const endTime = parseSrtTime(endStr);

    // 文本行
    const text = lines.slice(idx + 1).join('\n').trim();
    if (!text) continue;

    cues.push({
      index: index || cues.length + 1,
      startTime,
      endTime,
      startTimeStr: startStr,
      endTimeStr: endStr,
      text,
    });
  }

  return cues;
}

// 解析 VTT 字幕
export function parseVTT(content: string): SubtitleCue[] {
  const cues: SubtitleCue[] = [];
  const lines = content.replace(/\r\n/g, '\n').split('\n');

  let i = 0;
  // 跳过 WEBVTT 头部
  while (i < lines.length && !lines[i].includes('-->')) i++;

  while (i < lines.length) {
    const line = lines[i].trim();
    if (line.includes('-->')) {
      const [startStr, endStr] = line.split('-->').map(s => s.trim().split(' ')[0]);
      const startTime = parseVttTime(startStr);
      const endTime = parseVttTime(endStr);

      // 收集文本
      i++;
      const textLines: string[] = [];
      while (i < lines.length && lines[i].trim() !== '' && !lines[i].includes('-->')) {
        // 跳过 VTT cue 设置行（如 align:start）
        if (!lines[i].includes(':') || lines[i].includes('-->')) {
          textLines.push(lines[i].trim());
        }
        i++;
      }

      const text = textLines.join('\n').trim();
      if (text) {
        cues.push({
          index: cues.length + 1,
          startTime,
          endTime,
          startTimeStr: startStr,
          endTimeStr: endStr,
          text,
        });
      }
    } else {
      i++;
    }
  }

  return cues;
}

// 解析 LRC 歌词
export function parseLRC(content: string): SubtitleCue[] {
  const cues: SubtitleCue[] = [];
  const lines = content.replace(/\r\n/g, '\n').split('\n');
  const timeRegex = /\[(\d{1,2}):(\d{2})\.(\d{2,3})\]/g;

  for (const line of lines) {
    const matches = [...line.matchAll(timeRegex)];
    if (matches.length === 0) continue;

    // 提取文本（去掉所有时间标签）
    const text = line.replace(timeRegex, '').trim();
    if (!text) continue;

    for (const match of matches) {
      const m = parseInt(match[1]);
      const s = parseInt(match[2]);
      const ms = parseInt(match[3].padEnd(3, '0'));
      const startTime = m * 60 + s + ms / 1000;
      cues.push({
        index: cues.length + 1,
        startTime,
        endTime: startTime + 3, // 默认3秒
        startTimeStr: formatSrtTime(startTime),
        endTimeStr: formatSrtTime(startTime + 3),
        text,
      });
    }
  }

  // 按时间排序，并修正 endTime
  cues.sort((a, b) => a.startTime - b.startTime);
  for (let i = 0; i < cues.length; i++) {
    if (i < cues.length - 1) {
      cues[i].endTime = cues[i + 1].startTime;
      cues[i].endTimeStr = formatSrtTime(cues[i].endTime);
    }
    cues[i].index = i + 1;
  }

  return cues;
}

// 自动检测格式并解析
export function parseSubtitle(content: string, filename?: string): { cues: SubtitleCue[]; format: string } {
  const ext = filename ? filename.split('.').pop()?.toLowerCase() : '';

  if (ext === 'vtt' || content.trim().startsWith('WEBVTT')) {
    return { cues: parseVTT(content), format: 'vtt' };
  }
  if (ext === 'lrc' || (content.includes('[') && /\[\d{1,2}:\d{2}/.test(content))) {
    return { cues: parseLRC(content), format: 'lrc' };
  }
  // 默认按 SRT 解析
  return { cues: parseSRT(content), format: 'srt' };
}

// 将字幕 cues 序列化为 SRT 格式
export function cuesToSRT(cues: SubtitleCue[]): string {
  return cues.map((cue, i) => {
    return `${i + 1}\n${formatSrtTime(cue.startTime)} --> ${formatSrtTime(cue.endTime)}\n${cue.text}`;
  }).join('\n\n') + '\n';
}

// 将字幕 cues 序列化为 VTT 格式
export function cuesToVTT(cues: SubtitleCue[]): string {
  const body = cues.map((cue, i) => {
    return `${formatVttTime(cue.startTime)} --> ${formatVttTime(cue.endTime)}\n${cue.text}`;
  }).join('\n\n');
  return `WEBVTT\n\n${body}\n`;
}

// 将字幕 cues 序列化为 JSON 字符串（存储到数据库）
export function cuesToJSON(cues: SubtitleCue[]): string {
  return JSON.stringify(cues.map(c => ({
    s: Math.round(c.startTime * 1000) / 1000,
    e: Math.round(c.endTime * 1000) / 1000,
    t: c.text,
  })));
}

// 从 JSON 字符串解析 cues
export function cuesFromJSON(json: string): SubtitleCue[] {
  try {
    const arr = JSON.parse(json);
    return arr.map((c: any, i: number) => ({
      index: i + 1,
      startTime: c.s,
      endTime: c.e,
      startTimeStr: formatSrtTime(c.s),
      endTimeStr: formatSrtTime(c.e),
      text: c.t,
    }));
  } catch {
    return [];
  }
}
