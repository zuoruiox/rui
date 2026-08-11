import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 开始播种数据...');

  // 创建管理员账号
  const adminEmail = process.env.ADMIN_EMAIL || 'admin@mamababa.com';
  const adminPassword = process.env.ADMIN_PASSWORD || 'admin123456';
  const hashedPassword = await bcrypt.hash(adminPassword, 10);

  const admin = await prisma.user.upsert({
    where: { email: adminEmail },
    update: {},
    create: {
      email: adminEmail,
      password: hashedPassword,
      nickname: '管理员',
      role: 'admin',
      membershipTier: 'family',
    },
  });
  console.log('✅ 管理员账号创建成功:', admin.email);

  // 创建测试用户
  const testUser = await prisma.user.upsert({
    where: { email: 'test@mamababa.com' },
    update: {},
    create: {
      email: 'test@mamababa.com',
      password: await bcrypt.hash('test123456', 10),
      nickname: '测试用户',
      role: 'user',
      membershipTier: 'premium',
      children: {
        create: {
          name: '小明',
          gender: 'boy',
          ageGroup: 'preschool',
          interests: JSON.stringify(['汽车', '恐龙', '太空']),
        },
      },
    },
  });
  console.log('✅ 测试用户创建成功:', testUser.email);

  // 创建故事分类
  const categories = [
    { name: '经典童话', icon: '🏰', description: '格林童话、安徒生童话等经典故事', sortOrder: 1 },
    { name: '睡前故事', icon: '🌙', description: '温柔安静的短故事，适合哄睡', sortOrder: 2 },
    { name: '冒险故事', icon: '🗺️', description: '勇敢探索的冒险旅程', sortOrder: 3 },
    { name: '动物故事', icon: '🐰', description: '可爱动物们的有趣故事', sortOrder: 4 },
    { name: '科普故事', icon: '🔬', description: '自然科学、宇宙探索', sortOrder: 5 },
    { name: '习惯养成', icon: '⭐', description: '刷牙、分享、勇敢等好习惯', sortOrder: 6 },
    { name: '国学启蒙', icon: '📜', description: '成语故事、神话传说', sortOrder: 7 },
    { name: '友情故事', icon: '🤝', description: '关于友谊和分享', sortOrder: 8 },
  ];

  for (const cat of categories) {
    await prisma.storyCategory.upsert({
      where: { name: cat.name },
      update: { icon: cat.icon, description: cat.description, sortOrder: cat.sortOrder },
      create: cat,
    });
  }
  console.log('✅ 故事分类创建成功');

  // 获取分类ID
  const catMap: Record<string, string> = {};
  const allCats = await prisma.storyCategory.findMany();
  allCats.forEach(c => { catMap[c.name] = c.id; });

  // 创建示例故事
  const stories = [
    {
      title: '小兔子的冒险之旅',
      content: '从前，在一片美丽的大森林里，住着一只名叫白白的小兔子。白白有一身雪白的毛，两只长长的耳朵，还有一双红宝石般的眼睛。\n\n有一天，白白决定去森林深处探险。妈妈叮嘱它说："白白，要小心哦，记得在太阳落山前回家。"白白点点头，蹦蹦跳跳地出发了。\n\n一路上，白白遇到了许多好朋友。小松鼠在树上向它招手，小鹿在溪边喝水，蝴蝶在花丛中翩翩起舞。白白开心极了，它从来没有来过这么远的地方。\n\n突然，天空乌云密布，下起了大雨。白白赶紧跑到一棵大树下躲雨。这时候，它发现一只小刺猬被困在雨中，浑身发抖。白白毫不犹豫地把自己的大叶子伞递给了小刺猬。\n\n雨停了，太阳出来了，天空中出现了一道美丽的彩虹。小刺猬感激地说："谢谢你，小兔子！你真是个好孩子。"白白不好意思地笑了。\n\n回到家后，白白把今天的经历告诉了妈妈。妈妈温柔地摸了摸它的头说："我们的白白长大了，不仅勇敢，还很有爱心呢！"\n\n晚上，白白做了一个甜甜的梦，梦见自己和森林里所有的小动物一起，在彩虹下快乐地玩耍。',
      summary: '勇敢的小兔子白白在森林探险中帮助了小刺猬，学会了勇敢和友爱的故事。',
      theme: 'adventure',
      style: 'warm',
      targetAgeGroup: 'preschool',
      coverEmoji: '🐰',
      coverGradient: JSON.stringify(['#FFE0B2', '#FFCC80']),
      duration: 360,
      wordCount: 480,
      tags: JSON.stringify(['兔子', '森林', '冒险', '友爱']),
      characters: JSON.stringify(['白白', '小松鼠', '小鹿', '小刺猬']),
      categoryName: '冒险故事',
    },
    {
      title: '月亮上的小星星',
      content: '在遥远的夜空中，有一颗特别小的星星，它叫闪闪。闪闪比其他星星都小，发出的光也很微弱。\n\n闪闪总是很自卑，它问月亮妈妈："妈妈，为什么我这么小？别的星星都比我亮。"月亮妈妈笑着说："每个星星都有自己的光芒，只是你还没发现而已。"\n\n一天晚上，闪闪看到地面上有一个小女孩坐在窗边哭泣。原来小女孩怕黑，不敢一个人睡觉。闪闪决定帮助她。\n\n虽然闪闪的光很微弱，但它努力地闪烁着，把温柔的光芒洒在小女孩的窗前。小女孩看到了这颗小星星，觉得它就像一盏小夜灯，温暖又可爱。\n\n"小星星，你真好！"小女孩微笑着，慢慢进入了梦乡。\n\n从那以后，闪闪每天晚上都会来到小女孩的窗前，用自己微弱但温暖的光芒陪伴她。闪闪终于明白了，光芒不在于有多亮，而在于是否能温暖别人的心。',
      summary: '小星星闪闪用自己微弱的光芒陪伴怕黑的小女孩，明白了温暖他人的意义。',
      theme: 'bedtime',
      style: 'poetic',
      targetAgeGroup: 'toddler',
      coverEmoji: '⭐',
      coverGradient: JSON.stringify(['#BBDEFB', '#90CAF9']),
      duration: 280,
      wordCount: 380,
      tags: JSON.stringify(['星星', '月亮', '睡前', '勇气']),
      characters: JSON.stringify(['闪闪', '月亮妈妈', '小女孩']),
      categoryName: '睡前故事',
    },
    {
      title: '勇敢的小火车',
      content: '在山的那边，有一辆蓝色的小火车，它叫嘟嘟。嘟嘟每天都要拉着货物翻过高高的大山，送到山那边的小镇。\n\n有一天，山里下起了大雪，铁轨被厚厚的雪覆盖了。其他火车都说："这么大的雪，我们过不去了。"但是嘟嘟想到山那边的小朋友们正等着圣诞礼物，它决定试一试。\n\n"我能做到！我能做到！"嘟嘟一边给自己打气，一边慢慢地向前开。雪花打在它的脸上，寒风呼呼地吹，但嘟嘟没有放弃。\n\n它小心翼翼地爬过山坡，穿过隧道，终于在圣诞节的清晨到达了小镇。小朋友们看到满载礼物的小火车，都欢呼起来。\n\n嘟嘟虽然很累，但它心里暖洋洋的。它明白了，只要有勇气和决心，就没有克服不了的困难。',
      summary: '蓝色小火车嘟嘟冒着大雪为小朋友们送圣诞礼物，展现了勇气和坚持的力量。',
      theme: 'courage',
      style: 'fairy',
      targetAgeGroup: 'earlyElementary',
      coverEmoji: '🚂',
      coverGradient: JSON.stringify(['#C5CAE9', '#9FA8DA']),
      duration: 320,
      wordCount: 420,
      tags: JSON.stringify(['火车', '勇气', '坚持', '圣诞']),
      characters: JSON.stringify(['嘟嘟']),
      categoryName: '冒险故事',
    },
    {
      title: '小熊找朋友',
      content: '小熊胖胖刚搬到森林里，它一个朋友都没有，觉得很孤单。\n\n胖胖决定去找朋友。它先遇到了小猴子，小猴子正在树上荡秋千。"小猴子，我能和你做朋友吗？"胖胖问。小猴子说："你会荡秋千吗？"胖胖摇摇头，它太重了，树枝承受不住。\n\n接着胖胖遇到了小鱼，小鱼在河里游泳。"小鱼，我能和你做朋友吗？"小鱼说："你会游泳吗？"胖胖又摇摇头，它怕水。\n\n胖胖有点难过，坐在草地上哭了起来。这时候，小蜜蜂飞过来问："小熊，你怎么了？"胖胖说："我什么都不会，没有人愿意和我做朋友。"\n\n小蜜蜂笑着说："每个人都有自己的特长呀！你力气大，可以帮大家搬东西呀！"正好，小兔子的胡萝卜太多搬不动，胖胖过去轻轻松松就帮小兔子把胡萝卜运回了家。\n\n大家看到胖胖这么热心，都愿意和它做朋友了。胖胖终于明白，做真实的自己，用自己的方式帮助别人，就能交到好朋友。',
      summary: '小熊胖胖通过帮助别人找到了朋友，学会了接纳自己和乐于助人。',
      theme: 'friendship',
      style: 'warm',
      targetAgeGroup: 'preschool',
      coverEmoji: '🐻',
      coverGradient: JSON.stringify(['#C8E6C9', '#A5D6A7']),
      duration: 300,
      wordCount: 400,
      tags: JSON.stringify(['小熊', '友谊', '自信']),
      characters: JSON.stringify(['胖胖', '小猴子', '小鱼', '小蜜蜂', '小兔子']),
      categoryName: '友情故事',
    },
    {
      title: '魔法画笔',
      content: '小女孩朵朵有一支神奇的画笔，用它画出来的东西都会变成真的。\n\n朵朵用画笔画了好多好吃的糖果，糖果真的从画纸上飞了下来！她又画了一只小猫，小猫"喵"的一声就活了过来。朵朵开心极了。\n\n但是有一天，朵朵不小心画了一场大雨，雨水把整个院子都淹了。她又急又怕，不知道怎么办才好。\n\n这时候，奶奶走过来，温柔地说："朵朵，魔法画笔不是用来随心所欲的，而是要用来帮助别人的。"朵朵听了奶奶的话，想了想。\n\n她画了一个大大的太阳，阳光把雨水晒干了。她画了美丽的花朵，院子变得漂漂亮亮。她还画了好多书本和玩具，送给了孤儿院的小朋友们。\n\n朵朵终于明白了，拥有魔法不是最重要的，重要的是用自己的能力去帮助需要帮助的人。从那以后，朵朵成了一个善良又有爱心的小魔法师。',
      summary: '小女孩朵朵用魔法画笔帮助他人，学会了正确使用自己的能力。',
      theme: 'magic',
      style: 'fairy',
      targetAgeGroup: 'preschool',
      coverEmoji: '🎨',
      coverGradient: JSON.stringify(['#F8BBD0', '#F48FB1']),
      duration: 340,
      wordCount: 450,
      tags: JSON.stringify(['魔法', '善良', '帮助']),
      characters: JSON.stringify(['朵朵', '奶奶']),
      categoryName: '经典童话',
    },
    {
      title: '海底小纵队的奇妙旅行',
      content: '在蔚蓝的大海深处，有一支勇敢的海底小纵队。队长是聪明的小海豚波波，队员们有力气大的小鲸鱼壮壮、眼睛亮的小章鱼八爪，还有速度快的小剑鱼飞飞。\n\n一天，他们收到了一个求救信号——珊瑚礁里的小丑鱼迷路了！小纵队立刻出发去救援。\n\n他们穿过五彩斑斓的珊瑚丛，游过神秘的海底洞穴，躲过了巨大的水母群。在一片海草丛中，他们终于找到了害怕得发抖的小丑鱼。\n\n"别怕，我们送你回家！"波波温柔地说。小纵队围成一个保护圈，把小丑鱼护在中间，安全地送回了它的家。\n\n小丑鱼的爸爸妈妈非常感激，为小纵队准备了美味的海草蛋糕。大家一起在海底开起了派对，所有的海洋生物都来参加了。\n\n波波对队员们说："只要我们团结一心，就没有解决不了的困难！"大家都开心地点头，海底充满了欢声笑语。',
      summary: '海底小纵队团结协作帮助迷路的小丑鱼回家，展现了团队合作的力量。',
      theme: 'animals',
      style: 'humorous',
      targetAgeGroup: 'earlyElementary',
      coverEmoji: '🐬',
      coverGradient: JSON.stringify(['#80DEEA', '#4DD0E1']),
      duration: 400,
      wordCount: 520,
      tags: JSON.stringify(['海洋', '动物', '团队', '冒险']),
      characters: JSON.stringify(['波波', '壮壮', '八爪', '飞飞', '小丑鱼']),
      categoryName: '动物故事',
    },
  ];

  for (const story of stories) {
    const categoryId = catMap[story.categoryName];
    const { categoryName, ...storyData } = story;
    await prisma.story.upsert({
      where: { id: `seed-${story.title}` },
      update: {},
      create: {
        ...storyData,
        id: `seed-${story.title}`,
        categoryId,
        isAIGenerated: false,
        status: 'published',
      },
    });
  }
  console.log('✅ 示例故事创建成功，共', stories.length, '篇');

  // 系统配置
  const configs = [
    { key: 'app_name', value: '爸爸妈妈讲故事' },
    { key: 'app_version', value: '1.0.0' },
    { key: 'max_voice_models_free', value: '1' },
    { key: 'max_voice_models_premium', value: '4' },
    { key: 'max_voice_models_family', value: '6' },
    { key: 'daily_story_limit_free', value: '5' },
    { key: 'daily_ai_story_limit_free', value: '1' },
    { key: 'daily_ai_story_limit_premium', value: '20' },
    { key: 'min_recording_duration', value: '30' },
    { key: 'max_recording_duration', value: '300' },
  ];

  for (const config of configs) {
    await prisma.systemConfig.upsert({
      where: { key: config.key },
      update: { value: config.value },
      create: config,
    });
  }
  console.log('✅ 系统配置初始化成功');

  console.log('\n🎉 数据播种完成！');
  console.log('管理员账号:', adminEmail, '/', adminPassword);
  console.log('测试账号: test@mamababa.com / test123456');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
