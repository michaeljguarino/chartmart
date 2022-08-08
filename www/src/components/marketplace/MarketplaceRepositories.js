import {
  useEffect, useRef, useState,
} from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import {
  A,
  Br,
  Button, Div, Flex, H1, Span,
} from 'honorable'
import {
  FiltersIcon, Input, MagnifyingGlassIcon, RepositoryCard,
  Tab, Token,
} from 'pluralsh-design-system'
import Fuse from 'fuse.js'

import { EmptyState } from 'components/utils/EmptyState'

import { isEmpty } from 'lodash'

import { capitalize } from '../../utils/string'

import usePaginatedQuery from '../../hooks/usePaginatedQuery'

import { LoopingLogo } from '../utils/AnimatedLogo'

import { MARKETPLACE_QUERY } from './queries'

import MarketplaceSidebar from './MarketplaceSidebar'

const searchOptions = {
  keys: ['name', 'description', 'tags.tag'],
  threshold: 0.25,
}

const filterTokenStyles = {
  marginRight: 'xsmall',
  marginBottom: 'xsmall',
  flexShrink: 0,
  border: '1px solid border-fill-one',
  backgroundColor: 'fill-one-selected',
}

const sidebarWidth = 256 - 32

function RepoCardList({
  repositories, repoProps, maxWidth, size = 'small', stretchLastRow = false, ...props
}) {
  const flexBasis = '400px'

  // Workaround that will render empty columns to align the last row.
  // It is better to use bigger columns number to prevent issues on all kinds of viewports.
  function fillEmptyColumns(columns) {
    return (
      <>
        {[...Array(columns)].map((x, i) => (
          <Flex
            key={i}
            flexGrow={1}
            flexBasis={flexBasis}
          />
        ))}
      </>
    )
  }

  return (
    <Flex
      mx={-1}
      align="stretch"
      wrap="wrap"
      {...props}
    >
      {
        repositories.map(repository => (
          <Flex
            key={`${repository.id}flex`}
            px={0.75}
            marginBottom="large"
            width="auto"
            flexBasis={flexBasis}
            flexGrow={1}
            flexShrink={1}
            minWidth="250px"
            maxWidth={maxWidth || '800px'}
          >
            <RepositoryCard
              key={repository.id}
              as={Link}
              to={`/repository/${repository.id}`}
              color="text"
              textDecoration="none"
              width="100%"
              title={repository.name}
              imageUrl={repository.darkIcon || repository.icon}
              publisher={repository.publisher?.name}
              description={repository.description}
              tags={repository.tags.map(({ tag }) => tag)}
              priv={repository.private}
              installed={!!repository.installation}
              verified={repository.verified}
              size={size}
              {...repoProps}
            />
          </Flex>
        ))
      }
      {!stretchLastRow && fillEmptyColumns(10)}
    </Flex>
  )
}

function MarketplaceRepositories({ installed }) {
  const scrollRef = useRef()
  const [searchParams, setSearchParams] = useSearchParams()
  const categories = searchParams.getAll('category')
  const tags = searchParams.getAll('tag')
  const [search, setSearch] = useState('')
  const [areFiltersOpen, setAreFiltersOpen] = useState(true)

  const [repositories, loadingRepositories, hasMoreRepositories, fetchMoreRepositories] = usePaginatedQuery(MARKETPLACE_QUERY,
    {},
    data => data.repositories)

  const shouldRenderFeatured = !categories.length && !tags.length && !installed && !search

  useEffect(() => {
    const { current } = scrollRef

    if (!current) return

    function handleScroll(event) {
      if (!loadingRepositories && hasMoreRepositories && Math.abs(event.target.scrollTop - (event.target.scrollHeight - event.target.offsetHeight)) < 32) {
        fetchMoreRepositories()
      }
    }

    current.addEventListener('scroll', handleScroll)

    return () => {
      current.removeEventListener('scroll', handleScroll)
    }
  }, [scrollRef, fetchMoreRepositories, loadingRepositories, hasMoreRepositories])

  if (repositories.length === 0 && loadingRepositories) {
    return (
      <Flex
        pt={2}
        align="center"
        justify="center"
        flexGrow={1}
      >
        <LoopingLogo />
      </Flex>
    )
  }

  const sortedRepositories = repositories.slice()
    .sort((a, b) => a.name.localeCompare(b.name))
    .filter(repository => (categories.length ? categories.includes(repository.category.toLowerCase()) : true))
    .filter(repository => {
      if (!tags.length) return true

      const repositoryTags = repository.tags.map(({ tag }) => tag.toLowerCase())

      return tags.some(tag => repositoryTags.includes(tag))
    })
    .filter(repository => (installed ? repository.installation : true))

  const fuse = new Fuse(sortedRepositories, searchOptions)

  const resultRepositories = search ? fuse.search(search).map(({ item }) => item) : sortedRepositories

  function handleClearToken(key, value) {
    const existing = searchParams.getAll(key)

    setSearchParams({
      ...searchParams,
      [key]: existing.filter(v => v !== value),
    })
  }

  function handleClearTokens() {
    setSearchParams({})
  }

  function renderFeatured() {
    const featuredA = sortedRepositories.shift()
    const featuredB = sortedRepositories.shift()

    return (
      <>
        <H1 subtitle1>
          Featured Repositories
        </H1>
        <RepoCardList
          repositories={[featuredA, featuredB]}
          repoProps={{ featured: true }}
          marginTop="medium"
          maxWidth="100%"
          size="large"
          stretchLastRow
        />
      </>
    )
  }

  function renderTitle() {
    let title = installed ? 'Installed Repositories' : 'All Repositories'

    if (categories.length || tags.length) title += ', filtered'

    return title
  }

  return (
    <Flex
      direction="column"
      overflow="hidden"
      maxWidth-desktopLarge-up={1640}
      width-desktopLarge-up={1640}
      width-desktopLarge-down="100%"
    >
      <Flex
        direction="column"
      >
        <Flex
          marginHorizontal="large"
          flexShrink={0}
          direction="row"
          height={57}
          alignItems="flex-end"
        >
          <Link
            to="/marketplace"
            style={{ color: 'inherit', textDecoration: 'none' }}
          >
            <Tab active={!installed}>
              Marketplace
            </Tab>
          </Link>
          <Link
            to="/installed"
            style={{ color: 'inherit', textDecoration: 'none' }}
          >
            <Tab active={installed}>
              Installed
            </Tab>
          </Link>
          <Flex
            alignSelf="stretch"
            paddingBottom="xxsmall"
            paddingTop="xxsmall"
            justify="flex-end"
            flexGrow={1}
            borderBottom="1px solid border"
          >
            <Button
              tertiary
              small
              startIcon={<FiltersIcon />}
              onClick={() => setAreFiltersOpen(x => !x)}
            >
              Filters
            </Button>
          </Flex>
        </Flex>
      </Flex>
      <Flex
        flexGrow={1}
        marginTop="medium"
        overflow="hidden"
      >
        <Flex
          direction="column"
          flexGrow={1}
        >
          <Div position="relative">
            <Flex
              paddingHorizontal="large"
              align="stretch"
              wrap
              marginBottom="-8px"
            >
              <Div
                minWidth="210px"
                flex="1 1 210px"
                marginBottom="xsmall"
              >
                <Input
                  startIcon={(
                    <MagnifyingGlassIcon
                      size={14}
                    />
                  )}
                  placeholder="Search for a repository"
                  marginRight={[...categories, ...tags].length ? 'xsmall' : 'none'}
                  value={search}
                  onChange={event => setSearch(event.target.value)}
                />
              </Div>
              {categories.map(category => (
                <Token
                  {...filterTokenStyles}
                  onClose={() => handleClearToken('category', category)}
                >
                  {capitalize(category)}
                </Token>
              ))}
              {tags.map(tag => (
                <Token
                  {...filterTokenStyles}
                  onClose={() => handleClearToken('tag', tag)}
                >
                  {capitalize(tag)}
                </Token>
              ))}
              {!!(categories.length || tags.length) && (
                <Button
                  marginBottom="xsmall"
                  flexShrink={0}
                  tertiary
                  small
                  onClick={() => handleClearTokens()}
                >
                  Clear all
                </Button>
              )}
            </Flex>
            <Div
              flexShrink={0}
              height={16}
              width="100%"
              background="linear-gradient(0deg, transparent 0%, fill-zero 50%);"
              position="absolute"
              top="100%"
              zIndex={999}
            />
          </Div>
          <Div
            paddingTop="medium"
            paddingBottom="xxxlarge"
            paddingHorizontal="large"
            margin="xxsmall"
            overflowY="auto"
            overflowX="hidden"
            position="relative"
            ref={scrollRef}
          >
            {shouldRenderFeatured && renderFeatured()}
            <H1
              subtitle1
              marginTop={shouldRenderFeatured ? 'xlarge' : 0}
            >
              {renderTitle()}
            </H1>
            <RepoCardList
              repositories={resultRepositories}
              marginTop="medium"
            />
            {loadingRepositories && (
              <Flex
                marginTop="xlarge"
                align="center"
                justify="center"
              >
                <LoopingLogo />
              </Flex>
            )}
            {!resultRepositories?.length && installed && ![...searchParams]?.length && isEmpty(search) && (
              <EmptyState
                message="Looks like you haven't installed your first app yet."
                description={(
                  <Span>
                    Head back to the marketplace to select your first application! If you need
                    <Br />support installing your first app, read our&nbsp;
                    <A
                      inline
                      href="https://docs.plural.sh/getting-started/getting-started"
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      quickstart guide
                    </A>.
                  </Span>
                )}
              >
                <Button
                  as={Link}
                  to="/marketplace"
                >
                  Go to marketplace
                </Button>
              </EmptyState>
            )}
          </Div>
        </Flex>
        <Div
          marginRight={areFiltersOpen ? 'large' : `-${sidebarWidth}px`}
          transform={areFiltersOpen ? 'translateX(0)' : 'translateX(100%)'}
          opacity={areFiltersOpen ? 1 : 0}
          flexShrink={0}
          position="sticky"
          top={0}
          right={0}
          width={sidebarWidth}
          height="calc(100% - 16px)"
          overflowY="auto"
          border="1px solid border"
          backgroundColor="fill-one"
          borderRadius="large"
          transition="all 250ms ease"
          zIndex={9999}
        >
          <MarketplaceSidebar width="100%" />
        </Div>
      </Flex>
    </Flex>
  )
}

export default MarketplaceRepositories
