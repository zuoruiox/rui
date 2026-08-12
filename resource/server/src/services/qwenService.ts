// Qwen/DashScope LLM 服务
const fetch = require('node-fetch');

const DASHSCOPE_API_URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
const DASHSCOPE_API_KEY = process.env.DASHSCOPE_API_KEY || 'sk-746a481249d44d5db9dff32139183241';
const MODEL = 'qwen-plus';

interface GenerateStoryParams {
  theme: string;
  style: string;
  targetAge: string;
  wordCount: number;
  characters: string[];
  childName?: string;
  customPrompt?: string;
}

interface GeneratedStory {
  title: string;
  content: string;
  summary: string;
  tags: string[];
  characters: string[];
  coverEmoji: string;
  wordCount: number;
  suggestedDuration: number;
}

function buildSystemPrompt(): string {
  return `你是一位专业的儿童故事作家，擅长为不同年龄段的孩子创作温暖、有趣、富有教育意义的故事。
请严格按照用户要求创作故事，语言要生动、适合朗读，避免恐怖、暴力内容。
故事要有明确的开头、发展、高潮和结尾，传递积极正面的价值观。`;
}

function buildUserPrompt(params: GenerateStoryParams): string {
  const { theme, style, targetAge, wordCount, characters, childName, customPrompt } = params;

  let charDesc = '';
  if (characters.length > 0) {
    charDesc = `故事主角：${characters.join('、')}。`;
  }
  if (childName) {
    charDesc += `请将"${childName}"作为故事中的角色名字。`;
  }

  let prompt = `请创作一个儿童故事，要求如下：
- 主题：${theme}
- 风格：${style}
- 适合年龄：${targetAge}
- 字数：约${wordCount}字
${charDesc ? '- ' + charDesc : ''}`;

  if (customPrompt) {
    prompt += `\n- 额外要求：${customPrompt}`;
  }

  prompt += `\n\n请严格按照以下JSON格式返回故事内容，不要返回其他文字：
{
  "title": "故事标题",
  "content": "故事正文（分段，段落之间用\\n\\n分隔）",
  "summary": "50字以内的故事摘要",
  "tags": ["标签1", "标签2", "标签3"],
  "coverEmoji": "一个最能代表故事的emoji"
}`;

  return prompt;
}

export async function generateStoryWithQwen(params: GenerateStoryParams): Promise<GeneratedStory> {
  const messages = [
    { role: 'system', content: buildSystemPrompt() },
    { role: 'user', content: buildUserPrompt(params) }
  ];

  const payload = {
    model: MODEL,
    messages,
    max_tokens: 8192,
    temperature: 0.7,
    top_p: 0.9,
    stream: false
  };

  const maxRetries = 3;
  const retryDelays = [3000, 10000, 30000];

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(DASHSCOPE_API_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${DASHSCOPE_API_KEY}`
        },
        body: JSON.stringify(payload),
        timeout: 60000
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`API返回${response.status}: ${errorText}`);
      }

      const result: any = await response.json();

      if (result.choices && result.choices.length > 0) {
        const content = result.choices[0].message.content;
        const story = parseStoryResponse(content, params);
        return story;
      }

      throw new Error('API返回格式异常');
    } catch (err: any) {
      if (attempt === maxRetries) {
        throw new Error(`AI生成故事失败：${err.message}`);
      }
      const delay = retryDelays[attempt];
      console.warn(`Qwen API调用失败，${delay/1000}秒后重试（第${attempt+1}/${maxRetries}次）: ${err.message}`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw new Error('AI生成故事失败');
}

function parseStoryResponse(content: string, params: GenerateStoryParams): GeneratedStory {
  // 尝试从返回内容中提取 JSON
  let jsonStr = content.trim();

  // 去掉可能的 markdown 代码块标记
  const jsonMatch = jsonStr.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (jsonMatch) {
    jsonStr = jsonMatch[1].trim();
  }

  // 尝试找到第一个 { 和最后一个 }
  const firstBrace = jsonStr.indexOf('{');
  const lastBrace = jsonStr.lastIndexOf('}');
  if (firstBrace !== -1 && lastBrace !== -1) {
    jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
  }

  try {
    const parsed = JSON.parse(jsonStr);
    const storyContent = parsed.content || '';
    const wordCount = storyContent.replace(/\s/g, '').length;
    const suggestedDuration = Math.ceil(wordCount / 4); // 约每秒4个字

    return {
      title: parsed.title || '未命名故事',
      content: storyContent,
      summary: parsed.summary || '',
      tags: Array.isArray(parsed.tags) ? parsed.tags : [params.theme],
      characters: Array.isArray(parsed.characters) ? parsed.characters : params.characters,
      coverEmoji: parsed.coverEmoji || '📖',
      wordCount,
      suggestedDuration
    };
  } catch (err) {
    // JSON 解析失败，直接用文本作为故事内容
    const wordCount = content.replace(/\s/g, '').length;
    return {
      title: extractTitle(content) || `${params.theme}故事`,
      content: content,
      summary: content.substring(0, 50) + '...',
      tags: [params.theme],
      characters: params.characters,
      coverEmoji: getThemeEmoji(params.theme),
      wordCount,
      suggestedDuration: Math.ceil(wordCount / 4)
    };
  }
}

function extractTitle(text: string): string | null {
  const lines = text.split('\n').filter(l => l.trim());
  for (const line of lines) {
    const trimmed = line.trim().replace(/^#+\s*/, '').replace(/[《》""]/g, '');
    if (trimmed.length > 2 && trimmed.length < 30) {
      return trimmed;
    }
  }
  return null;
}

function getThemeEmoji(theme: string): string {
  const emojiMap: Record<string, string> = {
    '冒险': '🗺️', '友谊': '🤝', '家庭': '🏠', '动物': '🐰',
    '魔法': '✨', '太空': '🚀', '自然': '🌿', '睡前': '🌙',
    '勇气': '🦁', '善良': '💝', 'adventure': '🗺️', 'animals': '🐰',
    'bedtime': '🌙', 'magic': '✨'
  };
  return emojiMap[theme] || '📖';
}