import { useState } from 'react'
import { Box, Text } from 'grommet'
import { Copy } from 'forge-core'
import CopyToClipboard from 'react-copy-to-clipboard'
import truncate from 'lodash/truncate'

import { Toast } from 'pluralsh-design-system'

export function Copyable({
  text, pillText, displayText, onCopy,
}) {
  const [display, setDisplay] = useState(false)
  const [hover, setHover] = useState(false)

  return (
    <>
      <CopyToClipboard
        text={text}
        onCopy={() => (onCopy ? onCopy() : setDisplay(true))}
      >
        <Box
          onMouseEnter={() => setHover(true)}
          onMouseLeave={() => setHover(false)}
          style={{ cursor: 'pointer' }}
          direction="row"
          align="center"
          round="xsmall"
          gap="xsmall"
        >
          <Text size="small">{truncate(displayText || text, 40)}</Text>
          {hover && (
            <Box animation={{ type: 'fadeIn', duration: 200 }}>
              <Copy
                size="12px"
                color="dark-3"
              />
            </Box>
          )}
        </Box>
      </CopyToClipboard>
      {display && (
        <Toast
          severity="success"
          marginBottom="medium"
          marginRight="xxxxlarge"
        >{pillText}
        </Toast>
      )}
    </>
  )
}
