import PropTypes from 'prop-types';
import { useEffect, useState } from "react";

import { defineMessages, injectIntl } from 'react-intl';

import { Helmet } from 'react-helmet';

import { Map as ImmutableMap } from 'immutable';
import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';
import { createSelector } from 'reselect';

import { DragDropContext, Droppable, Draggable } from '@hello-pangea/dnd';
import { ReactComponent as MenuIcon } from '@material-symbols/svg-600/outlined/menu.svg';
import { ReactComponent as EmojiReactionIcon } from '@material-symbols/svg-600/outlined/mood.svg';

import { updateReactionDeck } from 'mastodon/actions/reaction_deck';
import { Button } from 'mastodon/components/button';
import ColumnHeader from 'mastodon/components/column_header';
import { Icon } from 'mastodon/components/icon';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import ScrollableList from 'mastodon/components/scrollable_list';
import Column from 'mastodon/features/ui/components/column';


import ReactionEmoji from './components/reaction_emoji';


// https://medium.com/@wbern/getting-react-18s-strict-mode-to-work-with-react-beautiful-dnd-47bc909348e4
/* eslint react/prop-types: 0 */
const StrictModeDroppable = ({ children, ...props }) => {
  const [enabled, setEnabled] = useState(false);
  useEffect(() => {
    const animation = requestAnimationFrame(() => setEnabled(true));
    return () => {
      cancelAnimationFrame(animation);
      setEnabled(false);
    };
  }, []);
  if (!enabled) {
    return null;
  }
  return <Droppable {...props}>{children}</Droppable>;
};
/* eslint react/prop-types: 0 */

const customEmojiMap = createSelector([state => state.get('custom_emojis')], items => items.reduce((map, emoji) => map.set(emoji.get('shortcode'), emoji), ImmutableMap()));

const messages = defineMessages({
  reaction_deck_add: { id: 'reaction_deck.add', defaultMessage: 'Add' },
  heading: { id: 'column.reaction_deck', defaultMessage: 'Reaction deck' },
});

const mapStateToProps = (state, props) => ({
  accountIds: state.getIn(['user_lists', 'favourited_by', props.params.statusId]),
  deck: state.get('reaction_deck'),
  emojiMap: customEmojiMap(state),
});

const mapDispatchToProps = (dispatch) => ({
  onChange: (emojis) => dispatch(updateReactionDeck(emojis)),
});

class ReactionDeck extends ImmutablePureComponent {

  static propTypes = {
    params: PropTypes.object.isRequired,
    deck: ImmutablePropTypes.list,
    emojiMap: ImmutablePropTypes.map,
    multiColumn: PropTypes.bool,
    intl: PropTypes.object.isRequired,
    onChange: PropTypes.func.isRequired,
  };

  deckToArray = () => {
    const { deck } = this.props;

    return deck.map((item) => item.get('name')).toArray();
  };

  handleReorder = (result) => {
    const newDeck = this.deckToArray();
    const deleted = newDeck.splice(result.source.index, 1);
    newDeck.splice(result.destination.index, 0, deleted[0]);
    this.props.onChange(newDeck);
  };

  handleChange = (index, emoji) => {
    const newDeck = this.deckToArray();
    newDeck[index] = emoji.native || emoji.id.replace(':', '');
    this.props.onChange(newDeck);
  };

  handleRemove = (index) => {
    const newDeck = this.deckToArray();
    newDeck.splice(index, 1);
    this.props.onChange(newDeck);
  };

  handleAdd = () => {
    const newDeck = this.deckToArray();
    newDeck.push('👍');
    this.props.onChange(newDeck);
  };

  render () {
    const { intl, deck, emojiMap, multiColumn } = this.props;

    if (!deck) {
      return (
        <Column>
          <LoadingIndicator />
        </Column>
      );
    }


    return (
      <Column bindToDocument={!multiColumn}>
        <ColumnHeader
          icon='smile-o'
          iconComponent={EmojiReactionIcon}
          title={intl.formatMessage(messages.heading)}
          multiColumn={multiColumn}
          showBackButton
        />

        <ScrollableList
          scrollKey='reaction_deck'
          bindToDocument={!multiColumn}
        >
          <DragDropContext onDragEnd={this.handleReorder}>
            <StrictModeDroppable droppableId='deckitems'>
              {(provided) => (
                <div className='deckitems reaction_deck_container' {...provided.droppableProps} ref={provided.innerRef}>
                  {deck.map((emoji, index) => (
                    <Draggable key={index} draggableId={'' + index} index={index}>
                      {(provided2) => (
                        <div className='reaction_deck_container__row' ref={provided2.innerRef} {...provided2.draggableProps}>
                          <span {...provided2.dragHandleProps}>
                            <Icon id='bars' icon={MenuIcon} className='handle'  />
                          </span>
                          <ReactionEmoji emojiMap={emojiMap}
                            emoji={emoji.get('name')}
                            index={index}
                            onChange={this.handleChange}
                            onRemove={this.handleRemove}
                            className='reaction_emoji'
                          />
                        </div>
                      )}
                    </Draggable>
                  ))}
                  {provided.placeholder}

                  <Button text={intl.formatMessage(messages.reaction_deck_add)} onClick={this.handleAdd} />
                </div>
              )}
            </StrictModeDroppable>
          </DragDropContext>
        </ScrollableList>

        <Helmet>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default connect(mapStateToProps, mapDispatchToProps)(injectIntl(ReactionDeck));
