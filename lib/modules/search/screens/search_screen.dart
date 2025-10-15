import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/search_result_item.dart';
import 'widgets/search_suggestions.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(context, user),
            ),
            
            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SearchBarWidget(
                  query: searchState.query,
                  onQueryChanged: (query) {
                    ref.read(searchProvider.notifier).setQuery(query);
                  },
                ),
              ),
            ),
            
            // Suggestions
            if (searchState.suggestions.isNotEmpty && searchState.query.isNotEmpty)
              SliverToBoxAdapter(
                child: SearchSuggestions(
                  suggestions: searchState.suggestions,
                  onSuggestionTap: (suggestion) {
                    ref.read(searchProvider.notifier).selectSuggestion(suggestion);
                  },
                ),
              ),
            
            // Error State
            if (searchState.hasError)
              SliverToBoxAdapter(
                child: _buildErrorState(context, searchState.errorMessage),
              ),
            
            // Loading State
            if (searchState.isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            
            // Search Results
            if (searchState.showResults)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final music = searchState.results[index];
                      return SearchResultItem(
                        music: music,
                        searchQuery: searchState.debouncedQuery,
                        onTap: () => _handleMusicTap(context, ref, music),
                      );
                    },
                    childCount: searchState.results.length,
                  ),
                ),
              ),
            
            // Empty State
            if (searchState.showEmptyState)
              SliverToBoxAdapter(
                child: _buildEmptyState(context, searchState.debouncedQuery),
              ),
            
            // Initial State
            if (!searchState.hasQuery && !searchState.isLoading)
              SliverToBoxAdapter(
                child: _buildInitialState(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            'Bem-vindo ao',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            ).createShader(bounds),
            child: Text(
              'Cântico Novo',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sua biblioteca musical definitiva',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          if (user != null) ...[
            const SizedBox(height: 8),
            Text(
              'Olá, ${user.fullName ?? user.email}!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String? message) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erro de Rede',
                  style: TextStyle(
                    color: Colors.red[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (message != null)
                  Text(
                    message,
                    style: TextStyle(color: Colors.red[700]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String query) {
    return Container(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum resultado para "$query"',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(64.0),
      child: Column(
        children: [
          Icon(
            Icons.music_note,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'Sua biblioteca de músicas em um só lugar',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Comece a buscar para encontrar suas letras e cifras',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _handleMusicTap(BuildContext context, WidgetRef ref, dynamic music) {
    // Registra acesso
    ref.read(searchProvider.notifier).trackMusicAccess(music);
    
    // Navega para tela de visualização
    Navigator.pushNamed(
      context,
      '/lyrics/view',
      arguments: {'musicId': music.id},
    );
  }
}
