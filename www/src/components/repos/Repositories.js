import React, {useState} from 'react'
import {Box, Text, Anchor, Stack} from 'grommet'
import {Trash} from 'grommet-icons'
import {useQuery, useMutation} from 'react-apollo'
import {useHistory} from 'react-router-dom'
import Scroller from '../utils/Scroller'
import {REPOS_Q, DELETE_REPO} from './queries'
import { Container } from './Integrations'
import HoveredBackground from '../utils/HoveredBackground'
import { chunk } from '../../utils/array'

function DeleteRepository({repo, publisherId}) {
  const [mutation] = useMutation(DELETE_REPO, {
    variables: {id: repo.id},
    update: (cache, { data: { deleteRepository } }) => {
      const prev = cache.readQuery({query: REPOS_Q, variables: {publisherId}})
      cache.writeQuery({query: REPOS_Q, variables: {publisherId}, data: {
        ...prev,
        repositories: {
          ...prev.repositories,
          edges: prev.repositories.edges.filter(({node}) => node.id !== deleteRepository.id)
        }
      }})
    }
  })

  return (
    <HoveredBackground>
      <Box
        accentable
        style={{cursor: 'pointer'}}
        background='white'
        pad='xsmall'
        round='xsmall'
        margin={{top: 'xsmall', right: 'xsmall'}}>
        <Trash size='15px' onClick={mutation} />
      </Box>
    </HoveredBackground>
  )
}

const ICON_WIDTH = '50px'

function RepositoryCellInner({repo, width, hover, setHover}) {
  let history = useHistory()
  const onClick = () => history.push(`/repositories/${repo.id}`)

  return (
    <Container
      pad='medium'
      style={{cursor: 'pointer'}}
      width={width}
      hover={hover}
      setHover={setHover}
      onClick={onClick}>
      <Box direction='row' gap='medium' fill='horizontal'>
        <Box align='center' justify='center' width={ICON_WIDTH}>
          <img alt='' width='50px' height='50px' src={repo.icon} />
        </Box>
        <Box gap='xxsmall' justify='center' width='100%'>
          <Anchor size='small' weight='bold' onClick={onClick}>
            {repo.name}
          </Anchor>
          <Text size='small'>
            {repo.description}
          </Text>
        </Box>
      </Box>
    </Container>
  )
}

export function RepositoryCell({repo, deletable, publisherId, width}) {
  const [hover, setHover] = useState(false)

  if (deletable && hover) {
    return (
      <Box width={width}>
        <Stack anchor='top-right' onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}>
          <RepositoryCellInner repo={repo} hover={hover} setHover={() => null} />
          <DeleteRepository repo={repo} publisherId={publisherId} />
        </Stack>
      </Box>
    )
  }

  return <RepositoryCellInner repo={repo} width={width} hover={hover} setHover={setHover} />
}

export function Repository({repo, hasNext, deletable, publisherId}) {
  let history = useHistory()
  return (
    <Box pad='small' direction='row' gap='small' border={hasNext ? 'bottom' : null}>
      <Box width='50px' heigh='50px'>
        <img alt='' width='50px' height='50px' src={repo.icon} />
      </Box>
      <Box gap='xxsmall' justify='center' width='100%'>
        <Anchor size='small' weight='bold' onClick={() => history.push(`/repositories/${repo.id}`)}>
          {repo.name}
        </Anchor>
        <Text size='small'>
          {repo.description}
        </Text>
      </Box>
      {deletable && (<DeleteRepository repo={repo} publisherId={publisherId} />)}
    </Box>
  )
}

export function RepositoryList({repositores: {edges, pageInfo}, fetchMore, publisher, deletable, columns}) {
  const width = Math.floor((100 - 10) / columns)
  return (
    <Scroller id='repositories'
      edges={Array.from(chunk(edges, columns))}
      style={{overflow: 'auto', height: '100%', width: '100%'}}
      mapper={(chunk) => (
        <Box key={chunk[0].node.id} direction='row' gap='small' fill='horizontal'>
          {chunk.map(({node}) => <RepositoryCell
                                    key={node.id}
                                    repo={node}
                                    publisherId={publisher && publisher.id}
                                    deletable={deletable}
                                    width={`${width}%`} />)}
        </Box>
      )}
      onLoadMore={() => {
        if (!pageInfo.hasNextPage) return

        fetchMore({
          variables: {cursor: pageInfo.endCursor},
          updateQuery: (prev, {fetchMoreResult}) => {
            const {edges, pageInfo} = fetchMoreResult.repositories
            return edges.length ? {
              ...prev,
              repositories: {
                ...prev.repositories,
                pageInfo,
                edges: [...prev.repositories.edges, ...edges]
              }
            } : prev
          }
        })
      }}
    />
  )
}

function Repositories({publisher, deletable, columns}) {
  const {loading, data, fetchMore} = useQuery(REPOS_Q, {variables: {publisherId: publisher.id}})
  if (loading || !data) return null

  return (
    <Box pad='small'>
      <RepositoryList
        repositores={data.repositories}
        fetchMore={fetchMore}
        deletable={deletable}
        publisher={publisher}
        columns={columns} />
    </Box>
  )
}

export default Repositories