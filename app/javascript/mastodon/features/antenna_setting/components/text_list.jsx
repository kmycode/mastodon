import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { injectIntl } from 'react-intl';

import ImmutablePropTypes from 'react-immutable-proptypes';
import { connect } from 'react-redux';

import { ReactComponent as DeleteIcon } from '@material-symbols/svg-600/outlined/delete.svg';

import { Button } from 'mastodon/components/button';
import { Icon } from 'mastodon/components/icon';
import { IconButton } from 'mastodon/components/icon_button';

class TextListItem extends PureComponent {

  static propTypes = {
    icon: PropTypes.string.isRequired,
    iconComponent: PropTypes.object.isRequired,
    value: PropTypes.string.isRequired,
    onRemove: PropTypes.func.isRequired,
  };

  handleRemove = () => {
    this.props.onRemove(this.props.value);
  };

  render () {
    const { icon, iconComponent, value } = this.props;

    return (
      <div className='setting-text-list-item'>
        <Icon id={icon} icon={iconComponent} />
        <span className='label'>{value}</span>
        <IconButton icon='trash' iconComponent={DeleteIcon} onClick={this.handleRemove} />
      </div>
    );
  }

}

class TextList extends PureComponent {

  static propTypes = {
    values: ImmutablePropTypes.list.isRequired,
    value: PropTypes.string.isRequired,
    disabled: PropTypes.bool,
    intl: PropTypes.object.isRequired,
    icon: PropTypes.string.isRequired,
    iconComponent: PropTypes.object.isRequired,
    label: PropTypes.string.isRequired,
    title: PropTypes.string.isRequired,
    onChange: PropTypes.func.isRequired,
    onAdd: PropTypes.func.isRequired,
    onRemove: PropTypes.func.isRequired,
  };

  handleChange = e => {
    this.props.onChange(e.target.value);
  };

  handleAdd = () => {
    this.props.onAdd();
  };

  handleSubmit = (e) => {
    e.preventDefault();
    this.handleAdd();
  };

  render () {
    const { icon, iconComponent, value, values, disabled, label, title } = this.props;

    return (
      <div className='setting-text-list'>
        {values.map((val) => (
          <TextListItem key={val} value={val} icon={icon} iconComponent={iconComponent} onRemove={this.props.onRemove} />
        ))}

        <form className='add-text-form' onSubmit={this.handleSubmit}>
          <label>
            <span style={{ display: 'none' }}>{label}</span>

            <input
              className='setting-text'
              value={value}
              disabled={disabled}
              onChange={this.handleChange}
              placeholder={label}
            />
          </label>

          <Button
            disabled={disabled || !value}
            text={title}
            onClick={this.handleAdd}
          />
        </form>
      </div>
    );
  }

}

export default connect()(injectIntl(TextList));
