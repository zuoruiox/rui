export interface PaginationQuery {
  page?: string;
  pageSize?: string;
}

export interface StoryQuery extends PaginationQuery {
  theme?: string;
  style?: string;
  targetAgeGroup?: string;
  categoryId?: string;
  keyword?: string;
  sortBy?: 'newest' | 'popular' | 'recommended';
  isPremium?: string;
}
