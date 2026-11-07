-- Ratings use 0.5 steps from 1.0 to 10.0, like the Flutter app (7.5 stays 7.5).
-- 0 is kept for deleted ratings.
ALTER TABLE ratings DROP CONSTRAINT ratings_score_check;
ALTER TABLE ratings ALTER COLUMN score TYPE numeric(3,1);
ALTER TABLE ratings ADD CONSTRAINT ratings_score_check
    CHECK (score = 0 OR (score BETWEEN 1 AND 10 AND score * 2 = floor(score * 2)));
