# Questions to ask: prompt library for owner review

Source: `assets/prompts/prompts.json` (version 1). **All prompts below are newly authored suggestions; spec 07 supplies only the rules (12 or more per topic, natural Egyptian Arabic, at most two follow-ups, audience any or elder) and one example question ("كانت أمك بتطبخ إيه في رمضان؟", used as `ramadan_cooking`).** The Arabic is unreviewed. You can edit the JSON in review.

Gender note for the Arabic: a few questions use masculine forms (for example فاكر، فخور، محظوظ). Decide whether to rewrite them neutrally or keep gendered variants.

## childhood_first_home

| id | audience | English | Arabic | follow-ups (en / ar) |
|---|---|---|---|---|
| `childhood_street` | any | What did the street you grew up on look like? | الشارع اللي اتربيت فيه كان شكله إيه؟ | Who lived next door? <br> مين كان ساكن جنبكم؟ |
| `childhood_first_memory` | any | What is the earliest thing you remember? | إيه أول حاجة تفتكرها في حياتك؟ | How old do you think you were? <br> كان عمرك كام تقريبًا؟ |
| `childhood_house` | any | Can you walk me through the house you grew up in, room by room? | وصفلي البيت اللي اتربيت فيه، أوضة أوضة. | Which room was your favourite? <br> أنهي أوضة كانت أحب أوضة ليك؟ |
| `childhood_games` | any | What games did you play as a child? | كنت بتلعب إيه وإنت صغير؟ | Who did you play with? / Did you make your own toys? <br> كنت بتلعب مع مين؟ / كنت بتعمل لعبك بإيديك؟ |
| `childhood_school` | any | What do you remember about your first day of school? | تفتكر إيه عن أول يوم في المدرسة؟ | Who took you there? <br> مين اللي وصلك؟ |
| `childhood_food` | any | What was the taste of home when you were a child? | أكل البيت وإنت صغير كان طعمه إيه؟ | Who cooked it? <br> مين كان بيطبخه؟ |
| `childhood_chores` | any | What chores did you have at home? | كان عليك شغل إيه في البيت؟ | Which one did you hate? <br> أنهي واحدة كنت بتكرهها؟ |
| `childhood_trouble` | any | What is the naughtiest thing you did as a child? | إيه أشقى حاجة عملتها وإنت صغير؟ | Did anyone find out? <br> حد اكتشفك؟ |
| `childhood_friend` | any | Who was your best friend as a child? | مين كان أقرب صاحب ليك وإنت صغير؟ | Where is he or she now? <br> هو دلوقتي فين؟ |
| `childhood_smell` | any | Is there a smell or a sound that takes you back to the house you grew up in? | في ريحة أو صوت بيرجعك لبيت طفولتك؟ | What does it remind you of? <br> بيفكرك بإيه؟ |
| `childhood_moving` | any | Did your family ever move house? What was that like? | عيلتك انتقلت من بيت لبيت قبل كده؟ كان إحساسك إيه؟ | What did you miss most? <br> إيه أكتر حاجة وحشتك؟ |
| `childhood_dream` | any | What did you want to be when you grew up? | كنت عايز تطلع إيه لما تكبر؟ | Did that change? <br> ده اتغير بعدين؟ |

## parents_grandparents

| id | audience | English | Arabic | follow-ups (en / ar) |
|---|---|---|---|---|
| `parents_mother` | any | What is the first thing you remember about your mother? | إيه أول حاجة تفتكرها عن أمك؟ | What was her voice like? <br> صوتها كان عامل إزاي؟ |
| `parents_father` | any | What is the first thing you remember about your father? | إيه أول حاجة تفتكرها عن أبوك؟ | What did he do for work? <br> كان بيشتغل إيه؟ |
| `parents_taught` | any | What is the most important thing your parents taught you? | إيه أهم حاجة أهلك علموهالك؟ | How did they teach it? <br> علموهالك إزاي؟ |
| `parents_grandparents_house` | any | What do you remember about your grandparents’ house? | تفتكر إيه عن بيت جدودك؟ | What did it smell like? <br> ريحته كانت عاملة إزاي؟ |
| `parents_grandmother` | any | Tell me about your grandmother. What was she like? | احكيلي عن جدتك. كانت عاملة إزاي؟ | What did she say that you still remember? <br> إيه الكلمة اللي كانت بتقولها وإنت لسه فاكرها؟ |
| `parents_grandfather` | any | Tell me about your grandfather. What was he like? | احكيلي عن جدك. كان عامل إزاي؟ | What was he known for? <br> كان معروف بإيه؟ |
| `parents_saying` | any | What sayings did your parents repeat all the time? | إيه الجمل اللي أهلك كانوا بيكرروها على طول؟ | Do you say any of them yourself? <br> إنت بتقول منها؟ |
| `parents_hard_times` | elder | What was the hardest time your parents went through? | إيه أصعب وقت مر على أهلك؟ | How did they get through it? <br> عدوه إزاي؟ |
| `parents_discipline` | any | How did your parents handle it when you did something wrong? | أهلك كانوا بيتصرفوا إزاي لما تغلط؟ | Do you think they were right? <br> شايف إنهم كانوا صح؟ |
| `parents_proud` | any | Was there a moment you knew your parents were proud of you? | في لحظة حسيت فيها إن أهلك فخورين بيك؟ | What happened? <br> إيه اللي حصل؟ |
| `parents_origin` | elder | Where did your family come from originally? | عيلتك أصلها منين؟ | How did they end up where you grew up? <br> وصلوا للمكان اللي اتربيت فيه إزاي؟ |
| `parents_name` | any | Who were you named after, and why? | إنت اتسميت على اسم مين، وليه؟ | Do you like your name? <br> اسمك بيعجبك؟ |

## how_parents_met

| id | audience | English | Arabic | follow-ups (en / ar) |
|---|---|---|---|---|
| `met_first_heard` | elder | How did you first hear about your future husband or wife? | سمعت عن شريك حياتك أول مرة إزاي؟ | Who told you? <br> مين اللي قالك؟ |
| `met_first_sight` | elder | What was the first time you saw each other like? | أول مرة شفتوا بعض كانت عاملة إزاي؟ | What did you think? <br> كنت فاكر إيه وقتها؟ |
| `met_family_visit` | elder | Tell me about the day the families first met. | احكيلي عن اليوم اللي العيلتين اتقابلوا فيه. | What did everyone wear? / Who was most nervous? <br> كل واحد كان لابس إيه؟ / مين كان أكتر واحد متوتر؟ |
| `met_proposal` | elder | How did the proposal happen? | الخطوبة حصلت إزاي؟ | Who was there? <br> مين كان موجود؟ |
| `met_before_wedding` | elder | What was the time between the engagement and the wedding like? | الفترة بين الخطوبة والفرح كانت عاملة إزاي؟ | Any funny moments? <br> حصلت مواقف مضحكة؟ |
| `met_first_gift` | elder | Do you remember the first gift you gave each other? | فاكر أول هدية اتبادلتوها؟ | Do you still have it? <br> لسه معاك؟ |
| `met_parents_story` | any | How did your parents tell the story of how they met? | أهلك كانوا بيحكوا قصة جوازهم إزاي؟ | Did the story change over the years? <br> القصة كانت بتتغير مع السنين؟ |
| `met_first_home` | any | Where did they live when they first got married? | هما سكنوا فين أول ما اتجوزوا؟ | What was it like? <br> المكان كان عامل إزاي؟ |
| `met_obstacles` | elder | Was there anything that almost stopped the marriage? | حصل حاجة كانت هتمنع الجواز؟ | How was it solved? <br> اتحلت إزاي؟ |
| `met_advice` | elder | What advice would you give a couple starting out? | إيه النصيحة اللي تقولها لأي اتنين بيبدأوا حياتهم؟ | Where did you learn it? <br> اتعلمتها منين؟ |
| `met_best_thing` | elder | What did you love most about your husband or wife when you met? | إيه أكتر حاجة حبيتها في شريك حياتك أول ما اتعرفتوا؟ | Is it still true? <br> لسه زي ما هي؟ |
| `met_song` | elder | Was there a song or a place that belonged to the two of you? | كان في أغنية أو مكان بتاعكم إنتو الاتنين؟ | Why that one? <br> ليه ده بالذات؟ |

## weddings_beginnings

| id | audience | English | Arabic | follow-ups (en / ar) |
|---|---|---|---|---|
| `wedding_day` | elder | Tell me about your wedding day from the morning. | احكيلي عن يوم فرحك من الصبح. | What was the first thing that happened? <br> إيه أول حاجة حصلت؟ |
| `wedding_dress` | elder | What did you wear, and who chose it? | لبست إيه، ومين اللي اختاره؟ | Do you still have it? <br> لسه محتفظ بيه؟ |
| `wedding_food` | any | What food was served at the wedding? | الأكل في الفرح كان إيه؟ | Who cooked it? <br> مين اللي طبخه؟ |
| `wedding_music` | any | Was there music or dancing? What do you remember? | كان في موسيقى أو رقص؟ تفتكر إيه؟ | Who danced the most? <br> مين كان أكتر واحد بيرقص؟ |
| `wedding_guests` | elder | Who was there, and who do you wish had been there? | مين كان موجود، ومين كنت تتمنى يكون موجود؟ | Why? <br> ليه؟ |
| `wedding_mishap` | any | Did anything go wrong on the day? How did it end up? | حصل حاجة غلط يوم الفرح؟ خلصت إزاي؟ | Do you laugh about it now? <br> بتضحك عليها دلوقتي؟ |
| `wedding_first_home` | elder | What was your first home as a married couple like? | بيتكم الأول بعد الجواز كان عامل إزاي؟ | What did you buy first? <br> إيه أول حاجة اشتريتوها؟ |
| `wedding_first_year` | elder | What was the first year of marriage like? | أول سنة جواز كانت عاملة إزاي؟ | What surprised you? <br> إيه اللي فاجئك؟ |
| `wedding_first_job` | any | Tell me about your first job. How did you get it? | احكيلي عن أول شغلانة ليك. جيتها إزاي؟ | What was your first pay? <br> أول مرتب كان كام؟ |
| `wedding_new_city` | any | Did you move somewhere new to start your life? What was that like? | انتقلت لمكان جديد عشان تبدأ حياتك؟ كان إحساسك إيه؟ | What did you miss? <br> إيه اللي وحشك؟ |
| `wedding_first_child` | elder | What do you remember about when your first child was born? | تفتكر إيه عن يوم ما أول ولد أو بنت ليك اتولد؟ | Who was with you? <br> مين كان معاك؟ |
| `wedding_money` | elder | How did you manage money when you were just starting out? | كنتوا بتدبروا الفلوس إزاي في بداية حياتكم؟ | What did you do without? <br> كنتوا بتستغنوا عن إيه؟ |

## ramadan_eid_traditions

| id | audience | English | Arabic | follow-ups (en / ar) |
|---|---|---|---|---|
| `ramadan_cooking` | any | What did your mother cook in Ramadan? | كانت أمك بتطبخ إيه في رمضان؟ | Which dish do you miss most? <br> أنهي أكلة وحشتك أكتر؟ |
| `ramadan_iftar` | any | What was iftar like at your house when you were young? | الفطار في بيتكم كان عامل إزاي وإنت صغير؟ | Who sat where? <br> كل واحد كان بيقعد فين؟ |
| `ramadan_lantern` | any | Do you remember the lanterns and the decorations? | فاكر الفوانيس والزينة؟ | Who made them? <br> مين كان بيعملهم؟ |
| `ramadan_musaharati` | any | Do you remember the musaharati calling people for suhoor? | فاكر المسحراتي وهو بينده على الناس؟ | What did he say? <br> كان بيقول إيه؟ |
| `ramadan_first_fast` | any | Do you remember your first fast? | فاكر أول صيام ليك؟ | Did you make it to sunset? <br> كملت لحد المغرب؟ |
| `eid_morning` | any | What was Eid morning like? | صباح العيد كان عامل إزاي؟ | What did you wear? <br> كنت بتلبس إيه؟ |
| `eid_eidiya` | any | What do you remember about getting the eidiya? | تفتكر إيه عن العيدية؟ | What did you buy with it? <br> كنت بتشتري بيها إيه؟ |
| `eid_kahk` | any | Who made the Eid kahk, and what was that day like? | مين كان بيعمل كحك العيد، واليوم ده كان عامل إزاي؟ | Who helped? <br> مين كان بيساعد؟ |
| `eid_visits` | any | Which relatives did you visit on Eid? | كنتوا بتزوروا مين في العيد؟ | Who did you look forward to seeing? <br> مين كنت مستني تشوفه؟ |
| `eid_adha` | any | What do you remember about Eid al-Adha in your family? | تفتكر إيه عن عيد الأضحى في عيلتكم؟ | How was the meat shared? <br> اللحمة كانت بتتقسم إزاي؟ |
| `ramadan_tradition_lost` | any | Is there a family tradition that we don’t do anymore? | في عادة كانت عندنا في العيلة ومبقيناش بنعملها؟ | Why did it stop? <br> ليه وقفت؟ |
| `ramadan_memory_best` | any | What is your happiest Ramadan or Eid memory? | إيه أحلى ذكرى ليك في رمضان أو العيد؟ | Who was there? <br> مين كان موجود؟ |

## life_events

| id | audience | English | Arabic | follow-ups (en / ar) |
|---|---|---|---|---|
| `life_big_change` | any | What was the biggest change in your life, and how did it happen? | إيه أكبر تغيير حصل في حياتك، وحصل إزاي؟ | Would you do it again? <br> كنت هتعمله تاني؟ |
| `life_hardest` | elder | What was the hardest time of your life, and what got you through it? | إيه أصعب وقت في حياتك، وإيه اللي عدّاك منه؟ | Who helped you? <br> مين وقف جنبك؟ |
| `life_proudest` | any | What are you most proud of? | إيه أكتر حاجة إنت فخور بيها؟ | Who knows about it? <br> مين عارف بيها؟ |
| `life_travel` | any | What is the farthest you have ever travelled, and why? | أبعد مكان سافرت له كان فين، وليه؟ | What did you bring back? <br> جبت معاك إيه؟ |
| `life_work` | any | What work did you do most of your life, and how did you start? | أغلب حياتك اشتغلت إيه، وبدأت إزاي؟ | What did you like most about it? <br> إيه أكتر حاجة كانت بتعجبك فيه؟ |
| `life_war_times` | elder | What do you remember about big events you lived through? | تفتكر إيه عن الأحداث الكبيرة اللي عشتها؟ | Where were you when it happened? <br> كنت فين وقتها؟ |
| `life_house` | any | Tell me about the house or place you lived longest. | احكيلي عن البيت أو المكان اللي عشت فيه أطول فترة. | What made it feel like home? <br> إيه اللي خلاه بيت بالنسبالك؟ |
| `life_turning_point` | any | Was there a decision that changed everything? | في قرار غيّر كل حاجة؟ | What if you had decided differently? <br> كان إيه هيحصل لو قررت غير كده؟ |
| `life_grandchildren` | elder | What do you remember about meeting your first grandchild? | تفتكر إيه عن أول مرة شفت فيها أول حفيد؟ | What did you feel? <br> حسيت بإيه؟ |
| `life_friends` | any | Who were the friends who mattered most in your life? | مين كانوا الأصحاب الأهم في حياتك؟ | How did you meet? <br> اتعرفتوا إزاي؟ |
| `life_loss` | elder | Who do you miss the most, and what would you say to them? | وحشك مين أكتر، وكنت هتقوله إيه؟ | What do you remember of them? <br> تفتكر إيه عنه؟ |
| `life_changed_world` | any | What is the biggest thing that has changed since you were young? | إيه أكبر حاجة اتغيرت من وإنت صغير؟ | Is it better or worse? <br> أحسن ولا أسوأ؟ |

## funny_memories

| id | audience | English | Arabic | follow-ups (en / ar) |
|---|---|---|---|---|
| `funny_family_joke` | any | What is a joke or saying that only our family understands? | إيه النكتة أو الجملة اللي العيلة بس هي اللي بتفهمها؟ | Where did it come from? <br> جت منين؟ |
| `funny_embarrassing` | any | What is the most embarrassing thing that ever happened to you? | إيه أكتر موقف محرج حصلك؟ | Can you laugh about it now? <br> بتضحك عليه دلوقتي؟ |
| `funny_trouble_school` | any | Did you ever get in trouble at school? What happened? | اتعاقبت في المدرسة قبل كده؟ إيه اللي حصل؟ | What did your parents say? <br> أهلك قالوا إيه؟ |
| `funny_prank` | any | What is the best prank you ever played, or had played on you? | إيه أحلى مقلب عملته أو اتعمل فيك؟ | Who was the victim? <br> مين كان الضحية؟ |
| `funny_nickname` | any | Did you have a nickname? Where did it come from? | كان ليك اسم دلع؟ جه منين؟ | Who still uses it? <br> مين لسه بيقوله؟ |
| `funny_travel` | any | Tell me about a trip where everything went wrong. | احكيلي عن رحلة كل حاجة فيها غلطت. | What did you do? <br> عملت إيه؟ |
| `funny_cooking` | any | Tell me about a time a meal turned out very differently than planned. | احكيلي عن مرة الأكل طلع غير اللي كنت متخيله. | Did anyone eat it? <br> حد أكله؟ |
| `funny_relative` | any | Who is the funniest person in our family, and why? | مين أكتر واحد دمه خفيف في العيلة، وليه؟ | What is the funniest thing they said? <br> إيه أضحك حاجة قالها؟ |
| `funny_neighbors` | any | Tell me about a funny neighbour or a street character. | احكيلي عن جار أو شخصية في الشارع كانت مضحكة. | What did they do? <br> كان بيعمل إيه؟ |
| `funny_wedding_mistake` | any | Do you remember a funny mistake at a family gathering? | فاكر غلطة مضحكة حصلت في تجمع عيلة؟ | Who laughed the hardest? <br> مين كان أكتر واحد ضحك؟ |
| `funny_first_phone` | any | What do you remember about the first time you used a new gadget, like a TV or a phone? | تفتكر إيه عن أول مرة استخدمت فيها حاجة جديدة، زي التلفزيون أو الموبايل؟ | What did you think of it? <br> كان رأيك فيها إيه؟ |
| `funny_lucky` | any | Tell me about a time you were really lucky. | احكيلي عن مرة كنت محظوظ فيها جدًا. | Did anyone else notice? <br> حد تاني خد باله؟ |

## lessons_for_future

| id | audience | English | Arabic | follow-ups (en / ar) |
|---|---|---|---|---|
| `lesson_advice_young` | any | What advice would you give your younger self? | إيه النصيحة اللي كنت هتقولها لنفسك وإنت صغير؟ | Would you have listened? <br> كنت هتسمعها؟ |
| `lesson_advice_grandchildren` | elder | What do you hope your grandchildren remember about you? | إيه اللي نفسك أحفادك يفتكروه عنك؟ | Why that? <br> ليه ده؟ |
| `lesson_mistake` | any | What is a mistake that taught you something important? | إيه الغلطة اللي علمتك حاجة مهمة؟ | What did you learn? <br> اتعلمت إيه؟ |
| `lesson_money` | any | What have you learned about money? | اتعلمت إيه عن الفلوس؟ | Who taught you? <br> مين علمك؟ |
| `lesson_family` | any | What makes a family stay close? | إيه اللي بيخلي العيلة قريبة من بعض؟ | What did your family do? <br> عيلتك كانت بتعمل إيه؟ |
| `lesson_patience` | any | When did you learn to be patient? | اتعلمت الصبر إمتى؟ | What taught you? <br> إيه اللي علمك؟ |
| `lesson_faith` | any | What has helped you through the hard days? | إيه اللي ساعدك في الأيام الصعبة؟ | Is there a verse, a prayer or a saying? <br> في آية أو دعاء أو جملة معينة؟ |
| `lesson_work` | any | What did work teach you about people? | الشغل علمك إيه عن الناس؟ | Who was the best boss or colleague? <br> مين كان أحسن مدير أو زميل؟ |
| `lesson_friends` | any | How do you choose who to trust? | بتختار مين تثق فيه إزاي؟ | Was there a time you were wrong? <br> حصل مرة كنت غلطان؟ |
| `lesson_regret` | elder | Is there anything you wish you had done differently? | في حاجة نفسك كنت عملتها غير كده؟ | What would you change? <br> إيه اللي كنت هتغيره؟ |
| `lesson_happy` | any | What does a good life look like to you? | الحياة الحلوة بالنسبالك شكلها إيه؟ | When did you feel that most? <br> إمتى حسيت بكده أكتر؟ |
| `lesson_one_thing` | any | If you could tell the family one thing, what would it be? | لو هتقول للعيلة حاجة واحدة بس، هتكون إيه؟ | Why that one? <br> ليه الحاجة دي؟ |
