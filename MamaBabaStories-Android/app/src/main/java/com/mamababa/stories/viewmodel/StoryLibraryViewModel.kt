package com.mamababa.stories.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mamababa.stories.data.model.Story
import com.mamababa.stories.data.model.StoryCategory
import com.mamababa.stories.data.repository.StoryRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class StoryLibraryUiState(
    val stories: List<Story> = emptyList(),
    val categories: List<StoryCategory> = StoryCategory.entries.filter { it != StoryCategory.CUSTOM },
    val selectedCategory: StoryCategory? = null,
    val searchQuery: String = "",
    val isLoading: Boolean = true,
    val isSearching: Boolean = false,
    val error: String? = null,
    val page: Int = 1,
    val hasMore: Boolean = true
)

class StoryLibraryViewModel(
    private val storyRepository: StoryRepository = StoryRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(StoryLibraryUiState())
    val uiState: StateFlow<StoryLibraryUiState> = _uiState.asStateFlow()

    private var loadJob: Job? = null
    private var searchJob: Job? = null

    init {
        loadStories()
    }

    fun loadStories(refresh: Boolean = false) {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            if (refresh) {
                _uiState.update { it.copy(page = 1, stories = emptyList(), hasMore = true) }
            }
            _uiState.update { it.copy(isLoading = true, error = null) }

            val state = _uiState.value
            val category = state.selectedCategory?.value

            storyRepository.getStories(
                category = category,
                page = state.page
            ).collect { result ->
                result.onSuccess { page ->
                    _uiState.update {
                        it.copy(
                            stories = if (refresh) page.list else (it.stories + page.list).distinctBy { s -> s.id },
                            isLoading = false,
                            hasMore = page.hasMore,
                            page = if (page.hasMore) it.page + 1 else it.page
                        )
                    }
                }.onFailure { e ->
                    _uiState.update { it.copy(isLoading = false, error = e.message) }
                }
            }
        }
    }

    fun selectCategory(category: StoryCategory?) {
        _uiState.update { it.copy(selectedCategory = category) }
        loadStories(refresh = true)
    }

    fun search(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
        if (query.isBlank()) {
            _uiState.update { it.copy(isSearching = false, stories = emptyList(), page = 1) }
            loadStories(refresh = true)
            return
        }

        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            _uiState.update { it.copy(isSearching = true, isLoading = true) }
            storyRepository.searchStories(query).collect { result ->
                result.onSuccess { page ->
                    _uiState.update {
                        it.copy(stories = page.list, isLoading = false, hasMore = page.hasMore)
                    }
                }.onFailure { e ->
                    _uiState.update { it.copy(isLoading = false, error = e.message) }
                }
            }
        }
    }

    fun toggleLike(story: Story) {
        viewModelScope.launch {
            storyRepository.toggleLike(story.id)
            // 乐观更新
            _uiState.update { state ->
                state.copy(stories = state.stories.map {
                    if (it.id == story.id) it.copy(isLiked = !it.isLiked) else it
                })
            }
        }
    }

    fun playStory(story: Story) {
        com.mamababa.stories.MamaBabaStoriesApp.getInstance()
            .audioPlayerManager.playStory(story, _uiState.value.stories)
    }

    fun loadMore() {
        if (_uiState.value.hasMore && !_uiState.value.isLoading) {
            loadStories()
        }
    }
}
