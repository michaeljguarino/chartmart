import React, {useState} from 'react'
import {Box, Text, TextInput} from 'grommet'
import {DocumentImage} from 'grommet-icons'
import {useMutation} from 'react-apollo'
import Button, {SecondaryButton} from '../utils/Button'
import {FilePicker} from 'react-file-picker'
import {CREATE_REPO, REPOS_Q} from './queries'
import {generatePreview} from '../../utils/file'

const LABEL_WIDTH = '90px'

export function RepoForm({image, setImage, state, setState, label, mutation, loading, update}) {
  return (
    <Box pad='medium' gap='medium'>
      <Box gap='xsmall'>
        <Text size='small' weight='bold'>1. Upload an image</Text>
        <Box direction='row' gap='small' align='center'>
          <Box
            width='70px'
            height='70px'
            border
            pad='xsmall'
            align='center'
            justify='center'>
            {image ? <img alt='' width='50px' height='50px' src={image.previewUrl} /> :
              <DocumentImage size='20px' />
            }
          </Box>
          <Box gap='xsmall'>
            <Text size='small'>{image ? image.file.name : 'Select an image'}</Text>
            <FilePicker
              extensions={['jpg', 'jpeg', 'png']}
              dims={{minWidth: 100, maxWidth: 500, minHeight: 100, maxHeight: 500}}
              onChange={(file) => generatePreview(file, setImage)}
            >
              <SecondaryButton round='xsmall' label='Upload an icon' />
            </FilePicker>
          </Box>
        </Box>
      </Box>
      <Box gap='xsmall'>
        <Text size='small' weight='bold'>2. Give it a name</Text>
        <TextInput
          labelWidth={LABEL_WIDTH}
          placeholder='a good name'
          value={state.name}
          onChange={(e) => setState({...state, name: e.target.value})} />
      </Box>
      <Box gap='xsmall'>
        <Text size='small' weight='bold'>3. Give it a quick description</Text>
        <TextInput
          label='description'
          labelWidth={LABEL_WIDTH}
          placeholder='a helpful description'
          value={state.description}
          onChange={(e) => setState({...state, description: e.target.value})} />
      </Box>
      <Box direction='row' justify='end'>
        <Button loading={loading} round='xsmall' label={update ? 'Update' : 'Create'} onClick={mutation} />
      </Box>
    </Box>
  )
}

function CreateRepository({publisher}) {
  const [state, setState] = useState({name: "", description: ""})
  const [image, setImage] = useState(null)
  const [mutation, {loading}] = useMutation(CREATE_REPO, {
    variables: {attributes: {...state, icon: image && image.file}},
    update: (cache, { data: { createRepository } }) => {
      const prev = cache.readQuery({ query: REPOS_Q, variables: {publisherId: publisher.id} })
      cache.writeQuery({query: REPOS_Q, variables: {publisherId: publisher.id}, data: {
        ...prev,
        repositories: {
          ...prev.repositories,
          edges: [{__typename: 'RepositoryEdge', node: createRepository}, ...prev.repositories.edges]
        }
      }})
    }
  })

  return (
    <RepoForm
      label='Create a new repository'
      image={image}
      setImage={setImage}
      state={state}
      setState={setState}
      mutation={mutation}
      loading={loading} />
  )
}

export default CreateRepository