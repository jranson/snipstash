import Foundation

// MARK: - Test Data (embedded for Test Data menu when Option is held)
// Contents mirror testdata/ for clipboard testing without file I/O.

enum TestData {
    static let jsonArray = """
    [
      {"id": 1, "name": "Alice", "department": "Engineering", "active": true},
      {"id": 2, "name": "Bob", "department": "Marketing", "active": false},
      {"id": 3, "name": "Charlie", "department": "Engineering", "active": true},
      {"id": 4, "name": "Diana", "department": "Sales", "active": true},
      {"id": 5, "name": "Eve", "department": "HR", "active": false}
    ]
    """

    static let jsonObject = """
    {
      "name": "myApp",
      "version": "1.0.0",
      "description": "A cool utility for macOS",
      "author": {
        "name": "Developer",
        "email": "dev@example.com"
      },
      "features": ["toc", "index", "editor"],
      "settings": {
        "theme": "dark",
        "fontSize": 14,
        "autoSave": true,
        "maxHistory": 100
      },
      "enabled": true,
      "lastUpdated": "2026-03-01T12:00:00Z"
    }
    """

    static let csv = """
    id,name,email,age,active,score
    1,Alice Johnson,alice@example.com,28,true,95.5
    2,Bob Smith,bob@example.com,35,false,82.3
    3,Charlie Brown,charlie@example.com,42,true,91.0
    4,Diana Prince,diana@example.com,31,true,88.7
    5,Eve Wilson,eve@example.com,27,false,76.2
    """

    static let tsv = """
    order_id\tcustomer\tproduct\tquantity\ttotal
    1001\tJohn Doe\tWidget A\t5\t125.00
    1002\tJane Smith\tWidget B\t2\t50.00
    1003\tBob Wilson\tGadget X\t1\t299.99
    1004\tAlice Brown\tWidget A\t10\t250.00
    1005\tCharlie Day\tGadget Y\t3\t89.97
    """

    static let psv = """
    product_id|product_name|category|price|in_stock
    SKU001|Wireless Mouse|Electronics|29.99|true
    SKU002|USB-C Cable|Accessories|12.50|true
    SKU003|Mechanical Keyboard|Electronics|149.00|false
    SKU004|Monitor Stand|Furniture|45.00|true
    SKU005|Webcam HD|Electronics|79.99|true
    """

    static let yaml = """
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: app-config
      namespace: production
      labels:
        app: clipboard-envy
        environment: prod
    data:
      database:
        host: db.example.com
        port: 5432
        name: clipboard_db
      features:
        - auto-detection
        - transformations
        - history
      settings:
        maxConnections: 100
        timeout: 30
        retryEnabled: true
      secrets:
        - name: API_KEY
          valueFrom: vault
        - name: DB_PASSWORD
          valueFrom: vault
    """

    /// Single URL with query params for testing Strip URL Params.
    static let urlWithParams = "https://example.com/search?q=hello+world&lang=en"

    static let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.KMUFsIDTnFmyG3nMiGM6H9FNFUROf3wh7SmqJp-QV30"

    static let urlEncoded = "True%21%20%E2%80%94%20nervous%20%E2%80%94%20very%2C%20very%20dreadfully%20nervous%20I%20had%20been%20and%20am%3B%20but%20why%20will%20you%20say%20that%20I%20am%20mad%3F%20The%20disease%20had%20sharpened%20my%20senses%20%E2%80%94%20not%20destroyed%20%E2%80%94%20not%20dulled%20them.%20Above%20all%20was%20the%20sense%20of%20hearing%20acute.%20I%20heard%20all%20things%20in%20the%20heaven%20and%20in%20the%20earth.%20I%20heard%20many%20things%20in%20hell.%20How%2C%20then%2C%20am%20I%20mad%3F%20Hearken%21%20and%20observe%20how%20healthily%20%E2%80%94%20how%20calmly%20I%20can%20tell%20you%20the%20whole%20story."

    static let mysqlCLI = """
    mysql> SELECT * FROM employees;
    +----+----------------+---------------+------------+--------+
    | id | name           | department    | hire_date  | active |
    +----+----------------+---------------+------------+--------+
    |  1 | Alice Johnson  | Engineering   | 2020-03-15 | 1      |
    |  2 | Bob Smith      | Marketing     | 2019-07-22 | 1      |
    |  3 | Charlie Brown | Engineering   | 2021-01-10 | 0      |
    |  4 | Diana Prince   | Sales         | 2018-11-05 | 1      |
    |  5 | Eve Wilson     | HR            | 2022-06-30 | NULL   |
    +----+----------------+---------------+------------+--------+
    5 rows in set (0.00 sec)
    """

    static let psqlCLI = """
     id |     name       |  department   | hire_date  | active
    ----+----------------+---------------+------------+--------
      1 | Alice Johnson  | Engineering   | 2020-03-15 | t
      2 | Bob Smith      | Marketing     | 2019-07-22 | t
      3 | Charlie Brown | Engineering   | 2021-01-10 | f
      4 | Diana Prince   | Sales         | 2018-11-05 | t
      5 | Eve Wilson     | HR            | 2022-06-30 | NULL
    (5 rows)
    """

    static let sqlite3CLI = """
    id  name            department     hire_date   active
    --  --------------  -------------  ----------  ------
    1   Alice Johnson   Engineering    2020-03-15  1
    2   Bob Smith       Marketing      2019-07-22  1
    3   Charlie Brown   Engineering    2021-01-10  0
    4   Diana Prince    Sales          2018-11-05  1
    5   Eve Wilson      HR             2022-06-30  NULL
    """

    /// Unsorted multiline list (with duplicates and empty lines) for testing sort/de-dupe/blank removal.
    static let instrumentsList = """
Violin
Trumpet
Cello

Oboe
Violin
Trombone
Flute

Clarinet
Harp
Cello
Viola
Timpani
Marimba

Bassoon
Snare Drum
Saxophone (Alto)
Cymbals
Saxophone (Baritone)

Triangle
Piano
Double Bass
Saxophone (Tenor)
French Horn
Tuba
Cornet
Piccolo

"""

    static let plainText = """
The Tell-Tale Heart

True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad? The disease had sharpened my senses — not destroyed — not dulled them. Above all was the sense of hearing acute. I heard all things in the heaven and in the earth. I heard many things in hell. How, then, am I mad? Hearken! and observe how healthily — how calmly I can tell you the whole story.

It is impossible to say how first the idea entered my brain; but once conceived, it haunted me day and night. Object there was none. Passion there was none. I loved the old man. He had never wronged me. He had never given me insult. For his gold I had no desire. I think it was his eye! yes, it was this! One of his eyes resembled that of a vulture — a pale blue eye, with a film over it. Whenever it fell upon me, my blood ran cold; and so by degrees — very gradually — I made up my mind to take the life of the old man, and thus rid myself of the eye forever.

Now this is the point. You fancy me mad. Madmen know nothing. But you should have seen me. You should have seen how wisely I proceeded — with what caution — with what foresight — with what dissimulation I went to work! I was never kinder to the old man than during the whole week before I killed him. And every night, about midnight, I turned the latch of his door and opened it — oh, so gently! And then, when I had made an opening sufficient for my head, I put in a dark lantern, all closed, closed, so that no light shone out, and then I thrust in my head. Oh, you would have laughed to see how cunningly I thrust it in! I moved it slowly — very, very slowly, so that I might not disturb the old man’s sleep. It took me an hour to place my whole head within the opening so far that I could see him as he lay upon his bed. Ha! — would a madman have been so wise as this? And then, when my head was well in the room, I undid the lantern cautiously — oh, so cautiously — cautiously (for the hinges creaked) — I undid it just so much that a single thin ray fell upon the vulture eye. And this I did for seven long nights — every night just at midnight — but I found the eye always closed; and so it was impossible to do the work; for it was not the old man who vexed me, but his Evil Eye. And every morning, when the day broke, I went boldly into the chamber, and spoke courageously to him, calling him by name in a hearty tone, and inquiring how he had passed the night. So you see he would have been a very profound old man, indeed, to suspect that every night, just at twelve, I looked in upon him while he slept.

Upon the eighth night I was more than usually cautious in opening the door. A watch’s minute hand moves more quickly than did mine. Never before that night had I felt the extent of my own powers — of my sagacity. I could scarcely contain my feelings of triumph. To think that there I was, opening the door, little by little, and he not even to dream of my secret deeds or thoughts. I fairly chuckled at the idea; and perhaps he heard me; for he moved on the bed suddenly, as if startled. Now you may think that I drew back — but no. His room was as black as pitch with the thick darkness, (for the shutters were close fastened, through fear of robbers,) and so I knew that he could not see the opening of the door, and I kept pushing it on steadily, steadily.

I had my head in, and was about to open the lantern, when my thumb slipped upon the tin fastening, and the old man sprang up in the bed, crying out — “Who’s there?”

I kept quite still and said nothing. For a whole hour I did not move a muscle, and in the meantime I did not hear him lie down. He was still sitting up in the bed listening; — just as I have done, night after night, hearkening to the death watches in the wall.

Presently I heard a slight groan, and I knew it was the groan of mortal terror. It was not a groan of pain or of grief — oh, no! — it was the low stifled sound that arises from the bottom of the soul when overcharged with awe. I knew the sound well. Many a night, just at midnight, when all the world slept, it has welled up from my own bosom, deepening, with its dreadful echo, the terrors that distracted me. I say I knew it well. I knew what the old man felt, and pitied him, although I chuckled at heart. I knew that he had been lying awake ever since the first slight noise, when he had turned in the bed. His fears had been ever since growing upon him. He had been trying to fancy them causeless, but could not. He had been saying to himself — “It is nothing but the wind in the chimney — it is only a mouse crossing the floor,” or “it is merely a cricket which has made a single chirp.” Yes, he has been trying to comfort himself with these suppositions: but he had found all in vain. All in vain; because Death, in approaching him had stalked with his black shadow before him, and enveloped the victim. And it was the mournful influence of the unperceived shadow that caused him to feel — although he neither saw nor heard — to feel the presence of my head within the room.

When I had waited a long time, very patiently, without hearing him lie down, I resolved to open a little — a very, very little crevice in the lantern. So I opened it — you cannot imagine how stealthily, stealthily — until, at length a single dim ray, like the thread of the spider, shot from out the crevice and fell upon the vulture eye.

It was open — wide, wide open — and I grew furious as I gazed upon it. I saw it with perfect distinctness — all a dull blue, with a hideous veil over it that chilled the very marrow in my bones; but I could see nothing else of the old man’s face or person: for I had directed the ray as if by instinct, precisely upon the damned spot.

And now have I not told you that what you mistake for madness is but over acuteness of the senses? — now, I say, there came to my ears a low, dull, quick sound, such as a watch makes when enveloped in cotton. I knew that sound well, too. It was the beating of the old man’s heart. It increased my fury, as the beating of a drum stimulates the soldier into courage.

But even yet I refrained and kept still. I scarcely breathed. I held the lantern motionless. I tried how steadily I could maintain the ray upon the eye. Meantime the hellish tattoo of the heart increased. It grew quicker and quicker, and louder and louder every instant. The old man’s terror must have been extreme! It grew louder, I say, louder every moment! — do you mark me well? I have told you that I am nervous: so I am. And now at the dead hour of the night, amid the dreadful silence of that old house, so strange a noise as this excited me to uncontrollable terror. Yet, for some minutes longer I refrained and stood still. But the beating grew louder, louder! I thought the heart must burst. And now a new anxiety seized me — the sound would be heard by a neighbor! The old man’s hour had come! With a loud yell, I threw open the lantern and leaped into the room. He shrieked once — once only. In an instant I dragged him to the floor, and pulled the heavy bed over him. I then smiled gaily, to find the deed so far done. But, for many minutes, the heart beat on with a muffled sound. This, however, did not vex me; it would not be heard through the wall. At length it ceased. The old man was dead. I removed the bed and examined the corpse. Yes, he was stone, stone dead. I placed my hand upon the heart and held it there many minutes. There was no pulsation. He was stone dead. His eye would trouble me no more.

If still you think me mad, you will think so no longer when I describe the wise precautions I took for the concealment of the body. The night waned, and I worked hastily, but in silence. First of all I dismembered the corpse. I cut off the head and the arms and the legs.

I then took up three planks from the flooring of the chamber, and deposited all between the scantlings. I then replaced the boards so cleverly, so cunningly, that no human eye — not even his — could have detected any thing wrong. There was nothing to wash out — no stain of any kind — no blood-spot whatever. I had been too wary for that. A tub had caught all — ha! ha!

When I had made an end of these labors, it was four o ‘clock — still dark as midnight. As the bell sounded the hour, there came a knocking at the street door. I went down to open it with a light heart, — for what had I now to fear? There entered three men, who introduced themselves, with perfect suavity, as officers of the police. A shriek had been heard by a neighbor during the night; suspicion of foul play had been aroused; information had been lodged at the police office, and they (the officers) had been deputed to search the premises.

I smiled, — for what had I to fear? I bade the gentlemen welcome. The shriek, I said, was my own in a dream. The old man, I mentioned, was absent in the country. I took my visitors all over the house. I bade them search — search well. I led them, at length, to his chamber. I showed them his treasures, secure, undisturbed. In the enthusiasm of my confidence, I brought chairs into the room, and desired them here to rest from their fatigues, while I myself, in the wild audacity of my perfect triumph, placed my own seat upon the very spot beneath which reposed the corpse of the victim.

The officers were satisfied. My manner had convinced them. I was singularly at ease. They sat, and while I answered cheerily, they chatted of familiar things. But, ere long, I felt myself getting pale and wished them gone. My head ached, and I fancied a ringing in my ears: but still they sat and still chatted. The ringing became more distinct: — it continued and became more distinct: I talked more freely to get rid of the feeling: but it continued and gained definitiveness — until, at length, I found that the noise was not within my ears.

No doubt I now grew very pale; — but I talked more fluently, and with a heightened voice. Yet the sound increased — and what could I do? It was a low, dull, quick sound — much such a sound as a watch makes when enveloped in cotton. I gasped for breath — and yet the officers heard it not. I talked more quickly — more vehemently; but the noise steadily increased. I arose and argued about trifles, in a high key and with violent gesticulations; but the noise steadily increased. Why would they not be gone? I paced the floor to and fro with heavy strides, as if excited to fury by the observations of the men — but the noise steadily increased. Oh God! what could I do? I foamed — I raved — I swore! I swung the chair upon which I had been sitting, and grated it upon the boards, but the noise arose over all and continually increased. It grew louder — louder — louder! And still the men chatted pleasantly, and smiled. Was it possible they heard not? Almighty God! — no, no! They heard! — they suspected! — they knew! — they were making a mockery of my horror! — this I thought, and this I think. But anything was better than this agony! Anything was more tolerable than this derision! I could bear those hypocritical smiles no longer! I felt that I must scream or die! — and now — again! — hark! louder! louder! louder! louder! —

“Villains!” I shrieked, “dissemble no more! I admit the deed! — tear up the planks! — here, here! — it is the beating of his hideous heart!”
"""
}

extension TestData {
    /// Sample fixed-width Docker containers table (docker ps).
    static let fixedWidthDockerContainers = """
CONTAINER ID   IMAGE                               COMMAND                  CREATED        STATUS          PORTS                                            NAMES
0174770c786b   grafana/grafana:11.6.0              "/run.sh"                2 months ago   Up 17 seconds   0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp   environment-grafana-1
59b86616bd90   telegraf:1.34-alpine                "/entrypoint.sh tele…"   2 months ago   Up 17 seconds   8092/udp, 8125/udp, 8094/tcp                  environment-telegraf-1
2636a2518a59   jaegertracing/all-in-one:1.67.0     "/go/bin/all-in-one-…"   2 months ago   Up 17 seconds   0.0.0.0:5775->5775/udp, [::]:5775->5775/udp   environment-jaeger-1
e75b1b85fc69   redis:latest                        "docker-entrypoint.s…"   2 months ago   Up 17 seconds   0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp   environment-redis-1
f93207515c6b   prom/prometheus:v3.2.1              "/bin/prometheus --c…"   2 months ago   Up 17 seconds   0.0.0.0:9090->9090/tcp, [::]:9090->9090/tcp   environment-prometheus-1
353c77a668f1   influxdb:2.7                        "/entrypoint.sh --re…"   2 months ago   Up 17 seconds   0.0.0.0:8086->8086/tcp, [::]:8086->8086/tcp   environment-influxdb2-1
76203b2c3a5d   clickhouse/clickhouse-server:25.3   "/entrypoint.sh"         2 months ago   Up 17 seconds   0.0.0.0:8123->8123/tcp, [::]:8123->8123/tcp   environment-clickhouse-1
"""
}
